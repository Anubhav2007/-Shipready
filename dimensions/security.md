## Dimension rules (complete)

### Dimension 1 — Security

Every rule below applies to every generation, with no exceptions.

| Rule | Requirement |
|---|---|
| Secrets | All secrets in `process.env`. Never hardcode. `.env.example` must be complete. |
| Input validation | Every API route must validate with Zod **before** any DB operation or business logic. Invalid input → 400 with structured error. |
| Rate limiting | Auth endpoints: 5 req / 15 min / IP. General API: 100 req / min / IP. Configure via `src/lib/rate-limit.ts`. |
| Password hashing | bcrypt, rounds = 12. Always. No MD5, SHA-*, or plain text. |
| Admin protection | All `/admin` pages and `/api/v1/admin/*` routes must check `session.user.role === 'ADMIN'` before executing. Return 403 otherwise. |
| Security headers | helmet (Express) or next-safe (Next.js). Configure: `Content-Security-Policy`, `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy`. |
| CORS | Whitelist explicit origins from `process.env.ALLOWED_ORIGINS`. Never `*` on auth or data routes. |
| JWT | Use `NEXTAUTH_SECRET` with minimum 32 characters. Rotate in production. Set appropriate expiry (7d default). |
| SQL injection | No raw SQL with user input. ORM or parameterized queries only. |
| File uploads | If description implies uploads: validate file type (whitelist, not blacklist), validate file size (max 10MB default), store on S3/Cloudflare R2, never serve from the app server. |
| Sensitive data | Never log passwords, tokens, or PII. Pino `redact` config must cover these fields. |
| Session | `httpOnly: true`, `secure: true` (production), `sameSite: 'lax'`. |
| CSRF | NextAuth.js v5 handles CSRF for auth routes. For non-auth mutations, use `SameSite=Lax` cookies as primary defense. |

**Standard rate limiter implementation:**

```typescript
// src/lib/rate-limit.ts
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'
import { logger } from './logger'

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
})

export const authRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, '15 m'),
  analytics: true,
  prefix: 'rl:auth',
})

export const apiRateLimit = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(100, '1 m'),
  analytics: true,
  prefix: 'rl:api',
})

export async function checkRateLimit(
  limiter: Ratelimit,
  identifier: string
): Promise<{ success: boolean; limit: number; remaining: number; reset: number }> {
  const result = await limiter.limit(identifier)
  if (!result.success) {
    logger.warn({ identifier }, 'Rate limit exceeded')
  }
  return result
}
```

**Standard API route pattern:**

```typescript
// src/app/api/v1/[resource]/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { auth } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { logger } from '@/lib/logger'
import { apiRateLimit, checkRateLimit } from '@/lib/rate-limit'
import { create[Resource]Schema } from '@/lib/validations/[resource]'
import { z } from 'zod'

export async function POST(req: NextRequest) {
  // 1. Rate limit
  const ip = req.headers.get('x-forwarded-for') ?? 'anonymous'
  const { success } = await checkRateLimit(apiRateLimit, ip)
  if (!success) {
    return NextResponse.json({ error: 'TOO_MANY_REQUESTS' }, { status: 429 })
  }

  // 2. Auth
  const session = await auth()
  if (!session?.user) {
    return NextResponse.json({ error: 'UNAUTHORIZED' }, { status: 401 })
  }

  // 3. Validate
  const body = await req.json()
  const result = create[Resource]Schema.safeParse(body)
  if (!result.success) {
    return NextResponse.json(
      { error: 'VALIDATION_ERROR', details: result.error.flatten().fieldErrors },
      { status: 400 }
    )
  }

  // 4. Business logic
  try {
    const resource = await prisma.[resource].create({ data: result.data })
    logger.info({ resourceId: resource.id, userId: session.user.id }, '[Resource] created')
    return NextResponse.json({ data: resource }, { status: 201 })
  } catch (error) {
    logger.error({ err: error }, 'Failed to create [resource]')
    return NextResponse.json({ error: 'INTERNAL_SERVER_ERROR' }, { status: 500 })
  }
}
```

---
