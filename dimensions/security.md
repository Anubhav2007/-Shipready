# Security Dimension — shipready v1.0.0

> **Max points: 15** | This dimension covers authentication, authorization, input validation, rate limiting, and secrets management. A perfect Security score means the app has no auth bypasses, no injectable inputs, no exposed secrets, and no unbounded attack surface — by default, not as an afterthought.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| Authentication (NextAuth, password hashing, sessions) | 4 | Plaintext passwords, missing session validation |
| Authorization (route guards, ownership checks) | 4 | Unprotected admin routes, missing ownership checks |
| Input validation (Zod on every boundary) | 3 | Any API route without schema validation |
| Rate limiting | 2 | Missing on auth endpoints |
| Secrets management | 2 | Hardcoded secrets, committed `.env` |

---

## Rule 1 — Authentication

### 1.1 — NextAuth v5 is the default

Every app with any concept of a "user" MUST implement full authentication via NextAuth v5, even if not explicitly requested. Login-implied keywords ("user", "account", "dashboard", "profile", "admin") trigger this by default.

### 1.2 — Password hashing

- Passwords MUST be hashed with `bcrypt` (cost factor ≥ 12) before storage. Never store plaintext or use reversible encryption for passwords.
- Never log passwords, even hashed ones, at any log level.

```typescript
// src/lib/auth/password.ts
import bcrypt from 'bcrypt'

const SALT_ROUNDS = 12

export async function hashPassword(plain: string): Promise<string> {
  return bcrypt.hash(plain, SALT_ROUNDS)
}

export async function verifyPassword(plain: string, hash: string): Promise<boolean> {
  return bcrypt.compare(plain, hash)
}
```

### 1.3 — NextAuth configuration

```typescript
// src/lib/auth.ts
import { NextAuthOptions } from 'next-auth'
import CredentialsProvider from 'next-auth/providers/credentials'
import { PrismaAdapter } from '@auth/prisma-adapter'
import { prisma } from './prisma'
import { verifyPassword } from './auth/password'
import { loginSchema } from './validations/auth'
import { logger } from './logger'

export const authOptions: NextAuthOptions = {
  adapter: PrismaAdapter(prisma),
  session: { strategy: 'jwt', maxAge: 30 * 24 * 60 * 60 }, // 30 days
  pages: { signIn: '/login', error: '/login' },
  providers: [
    CredentialsProvider({
      credentials: { email: {}, password: {} },
      async authorize(credentials) {
        const parsed = loginSchema.safeParse(credentials)
        if (!parsed.success) return null

        const user = await prisma.user.findUnique({
          where: { email: parsed.data.email },
          select: { id: true, email: true, name: true, password: true, role: true },
        })

        // Constant-shape response regardless of which check fails —
        // prevents user-enumeration via timing or error differences.
        if (!user) {
          logger.warn({ email: parsed.data.email }, 'Login attempt: unknown email')
          return null
        }

        const isValid = await verifyPassword(parsed.data.password, user.password)
        if (!isValid) {
          logger.warn({ userId: user.id }, 'Login attempt: invalid password')
          return null
        }

        return { id: user.id, email: user.email, name: user.name, role: user.role }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id
        token.role = (user as { role: string }).role
      }
      return token
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string
        session.user.role = token.role as string
      }
      return session
    },
  },
  secret: process.env.NEXTAUTH_SECRET,
}
```

### 1.4 — Session validation

Every API route and server component that requires a logged-in user MUST validate the session server-side. Never trust client-supplied user IDs.

```typescript
// ❌ Prohibited — trusts client-supplied userId
const userId = request.headers.get('x-user-id')

// ✅ Required — session derived server-side from signed JWT
const session = await getServerSession(authOptions)
if (!session) {
  return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
}
const userId = session.user.id
```

### 1.5 — Email verification (when email provider is configured)

If Resend/email is included, new accounts SHOULD have an `emailVerified` field. Unverified accounts may log in but should be restricted from sensitive actions (payments, admin requests) until verified.

---

## Rule 2 — Authorization

### 2.1 — Route protection via middleware

`src/middleware.ts` MUST enforce auth on all protected route groups, redirecting unauthenticated users to `/login`.

```typescript
// src/middleware.ts
import { NextResponse } from 'next/server'
import { getToken } from 'next-auth/jwt'
import type { NextRequest } from 'next/server'

const PUBLIC_PATHS = ['/login', '/register', '/api/health', '/api/auth']

export async function middleware(request: NextRequest) {
  const { pathname } = request.nextUrl

  if (PUBLIC_PATHS.some((p) => pathname.startsWith(p))) {
    return applySecurityHeaders(NextResponse.next())
  }

  const token = await getToken({ req: request, secret: process.env.NEXTAUTH_SECRET })

  if (!token) {
    if (pathname.startsWith('/api')) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
    }
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('callbackUrl', pathname)
    return NextResponse.redirect(loginUrl)
  }

  // Admin route guard — never trust the path alone, verify role on token
  if (pathname.startsWith('/admin') && token.role !== 'ADMIN') {
    return NextResponse.redirect(new URL('/', request.url))
  }

  return applySecurityHeaders(NextResponse.next())
}

function applySecurityHeaders(response: NextResponse) {
  response.headers.set('X-Frame-Options', 'DENY')
  response.headers.set('X-Content-Type-Options', 'nosniff')
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin')
  response.headers.set('X-XSS-Protection', '1; mode=block')
  response.headers.set(
    'Permissions-Policy',
    'camera=(), microphone=(), geolocation=()'
  )
  return response
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico).*)'],
}
```

### 2.2 — Ownership checks (mandatory on every resource mutation)

Authentication alone is not authorization. Every route that reads, updates, or deletes a specific resource MUST verify the requesting user owns it (or is an admin) — never rely on the URL ID alone.

```typescript
// ❌ Prohibited — any logged-in user can edit any booking
export async function PATCH(request: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return unauthorized()
  await prisma.booking.update({ where: { id: params.id }, data: body })
}

// ✅ Required — ownership verified before mutation
export async function PATCH(request: Request, { params }: { params: { id: string } }) {
  const session = await getServerSession(authOptions)
  if (!session) return unauthorized()

  const booking = await prisma.booking.findUnique({
    where: { id: params.id },
    select: { userId: true },
  })

  if (!booking) {
    return NextResponse.json({ error: 'Not found' }, { status: 404 })
  }

  if (booking.userId !== session.user.id && session.user.role !== 'ADMIN') {
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  }

  const updated = await prisma.booking.update({ where: { id: params.id }, data: body })
  return NextResponse.json(updated)
}
```

### 2.3 — Admin panel hard requirement

Any description containing "admin", "manage", or "dashboard" implies a protected `/admin` route group. The admin layout MUST verify role server-side in addition to the middleware check (defense in depth):

```typescript
// src/app/admin/layout.tsx
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { redirect } from 'next/navigation'

export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const session = await getServerSession(authOptions)
  if (!session || session.user.role !== 'ADMIN') {
    redirect('/')
  }
  return <>{children}</>
}
```

---

## Rule 3 — Input Validation

### 3.1 — Zod on every boundary, no exceptions

Every API route MUST validate `body`, `query params`, and `route params` with Zod before touching the database or business logic. There is no such thing as a "trusted" input — even internal admin tools validate.

```typescript
// src/lib/validations/booking.ts
import { z } from 'zod'

export const createBookingSchema = z.object({
  restaurantId: z.string().uuid(),
  date: z.coerce.date().refine((d) => d > new Date(), 'Date must be in the future'),
  guestCount: z.number().int().min(1).max(20),
  notes: z.string().max(500).optional(),
})

export const updateBookingSchema = createBookingSchema.partial()

export const bookingIdSchema = z.object({
  id: z.string().uuid(),
})
```

```typescript
// Usage in route handler
const body = await request.json()
const parsed = createBookingSchema.safeParse(body)

if (!parsed.success) {
  return NextResponse.json(
    { error: 'Validation failed', details: parsed.error.format() },
    { status: 400 }
  )
}
// parsed.data is now fully typed and safe to use
```

### 3.2 — Sanitize, never trust, free-text fields

Any field rendered as HTML (rich text, comments, descriptions) MUST be sanitized before storage or rendering to prevent XSS. Use a library like `isomorphic-dompurify` if rich text is rendered as HTML; prefer storing and rendering as plain text/Markdown when rich formatting isn't required.

### 3.3 — SQL injection — prevented by ORM, but verify raw queries

Prisma parameterizes all queries by default, eliminating SQL injection risk for standard query builder usage. **Any** use of `prisma.$queryRawUnsafe` is prohibited. `prisma.$queryRaw` with tagged template literals is acceptable since it auto-parameterizes:

```typescript
// ❌ Prohibited — string concatenation, injectable
await prisma.$queryRawUnsafe(`SELECT * FROM "User" WHERE email = '${email}'`)

// ✅ Acceptable — tagged template, auto-parameterized
await prisma.$queryRaw`SELECT * FROM "User" WHERE email = ${email}`

// ✅ Preferred — use the query builder when possible
await prisma.user.findUnique({ where: { email } })
```

### 3.4 — File upload validation

If file/image upload is implied, validate:
- File type via MIME type AND magic-byte sniffing (never trust the extension or client-supplied `Content-Type` alone)
- File size limit (enforce both client-side UX hint and server-side hard limit)
- Filename sanitization — never use the client-supplied filename directly for storage; generate a UUID-based key

---

## Rule 4 — Rate Limiting

### 4.1 — Required on all auth endpoints

| Endpoint | Limit |
|---|---|
| `/api/auth/callback/credentials` (login) | 5 requests / 15 min per IP |
| `/api/auth/register` | 5 requests / 15 min per IP |
| `/api/auth/forgot-password` | 3 requests / 15 min per IP |
| General authenticated API | 100 requests / min per user |
| Public unauthenticated API | 20 requests / min per IP |

### 4.2 — Implementation (Upstash Redis)

```typescript
// src/lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
})

export const authRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, '15 m'),
  prefix: 'ratelimit:auth',
})

export const apiRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(100, '1 m'),
  prefix: 'ratelimit:api',
})
```

```typescript
// Usage in a route handler
import { authRateLimit } from '@/lib/rate-limit'

export async function POST(request: NextRequest) {
  const ip = request.headers.get('x-forwarded-for') ?? '127.0.0.1'
  const { success, remaining } = await authRateLimit.limit(ip)

  if (!success) {
    return NextResponse.json(
      { error: 'Too many attempts. Please try again later.' },
      { status: 429, headers: { 'Retry-After': '900' } }
    )
  }
  // continue with login logic
}
```

### 4.3 — Identify by user ID for authenticated routes, IP for public routes

Rate limit keys MUST use the authenticated user's ID when available (more accurate, harder to evade via IP rotation) and fall back to IP for unauthenticated endpoints.

---

## Rule 5 — Secrets Management

### 5.1 — Absolute prohibitions

- No secret, API key, password, or connection string may ever be hardcoded in source files.
- `.env.local` and `.env.production` MUST be in `.gitignore`.
- `.env.example` contains only placeholder values, never real credentials.
- No secret may be logged, even at debug level (`logger.ts` redact list covers this — see Environment dimension).

### 5.2 — NEXTAUTH_SECRET strength

Must be ≥ 32 characters, generated via `openssl rand -base64 32`. Validated at startup via the Zod env schema (see Environment dimension Rule 1).

### 5.3 — CORS — explicit origin whitelist, never wildcard

```typescript
// ❌ Prohibited
response.headers.set('Access-Control-Allow-Origin', '*')

// ✅ Required
const ALLOWED_ORIGINS = [
  process.env.NEXTAUTH_URL!,
  'https://app.example.com',
]

const origin = request.headers.get('origin')
if (origin && ALLOWED_ORIGINS.includes(origin)) {
  response.headers.set('Access-Control-Allow-Origin', origin)
  response.headers.set('Access-Control-Allow-Credentials', 'true')
}
```

### 5.4 — Security headers (set in middleware, applied globally)

| Header | Value | Purpose |
|---|---|---|
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing attacks |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | Disable unused browser APIs |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains` | Force HTTPS (production only) |

---

## Deductions reference (Security)

| Violation | Deduction |
|---|---|
| Plaintext password storage | -5 |
| Unprotected admin route | -5 |
| Missing ownership check on a resource mutation | -3 per route |
| API route without Zod validation | -2 per route |
| Hardcoded secret anywhere in source | -5 per instance |
| `prisma.$queryRawUnsafe` used | -5 per instance |
| Wildcard CORS (`*`) | -3 |
| Missing rate limit on login/register | -2 |
| Client-supplied user ID trusted without session check | -5 |
| `.env.local` not in `.gitignore` | -3 |
| Security headers missing from middleware | -2 |

---

## Checklist (use before scoring)

- [ ] NextAuth v5 configured with Credentials provider (+ OAuth if implied)
- [ ] Passwords hashed with bcrypt, cost ≥ 12
- [ ] No plaintext or reversibly-encrypted passwords anywhere
- [ ] `middleware.ts` enforces auth on all protected routes
- [ ] `middleware.ts` enforces role check on `/admin/*`
- [ ] Admin layout has server-side role re-check (defense in depth)
- [ ] Every resource mutation route checks `resource.userId === session.user.id` or admin role
- [ ] Every API route validates input with a Zod schema
- [ ] No `prisma.$queryRawUnsafe` anywhere in the codebase
- [ ] Rate limiting applied to login, register, and password reset
- [ ] Rate limiting applied to general API (100/min) and public API (20/min)
- [ ] No hardcoded secrets — all in `.env.local`, referenced via `process.env`
- [ ] `.gitignore` excludes `.env.local` and `.env.production`
- [ ] `.env.example` has placeholders only, no real values
- [ ] CORS uses explicit origin whitelist, never `*`
- [ ] Security headers (`X-Frame-Options`, `X-Content-Type-Options`, etc.) set globally in middleware
- [ ] `NEXTAUTH_SECRET` is ≥ 32 characters and validated at startup

---

*Security dimension — shipready v1.0.0*