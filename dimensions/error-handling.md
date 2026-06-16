# Error Handling Dimension — shipready v1.0.0

> **Max points: 10** | This dimension covers consistent API error shapes, global error boundaries, structured logging, and the prohibition on leaking internal details to clients. A perfect Error Handling score means every failure mode — expected or not — produces a predictable, safe, loggable response.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| Consistent API error response shape | 3 | Any route returns a different error shape |
| Global error boundaries (`error.tsx`, try/catch in routes) | 2 | Unhandled exceptions crash the route or leak a stack trace |
| Structured logging (Pino, never `console.log`) | 2 | `console.log`/`console.error` used anywhere |
| No internal details exposed to clients | 2 | Stack traces, DB errors, or file paths returned in responses |
| Correct HTTP status codes | 1 | Wrong status code for the error class (e.g., 200 on failure) |

---

## Rule 1 — Consistent API Error Shape

### 1.1 — The one true error shape

Every error response from every API route, with zero exceptions, MUST conform to:

```typescript
interface ApiErrorResponse {
  error: string              // human-readable, safe to display
  details?: unknown          // optional structured detail (e.g., Zod field errors)
  code?: string               // optional machine-readable error code for client logic
}
```

```typescript
// ✅ Validation failure
{ "error": "Validation failed", "details": { "email": { "_errors": ["Invalid email"] } } }

// ✅ Not found
{ "error": "Booking not found" }

// ✅ Forbidden
{ "error": "You do not have permission to modify this resource" }

// ✅ Rate limited
{ "error": "Too many requests. Please try again later.", "code": "RATE_LIMITED" }

// ❌ Prohibited — inconsistent shape
{ "message": "something broke" }
{ "success": false, "err": "..." }
{ "statusCode": 500, "error": "Internal Server Error", "stack": "Error: ..." }
```

### 1.2 — Centralized error response helper

To guarantee consistency, never construct error responses inline more than once per pattern — use shared helpers.

```typescript
// src/lib/api-response.ts
import { NextResponse } from 'next/server'
import { ZodError } from 'zod'

export function errorResponse(message: string, status: number, details?: unknown) {
  return NextResponse.json({ error: message, ...(details ? { details } : {}) }, { status })
}

export function validationErrorResponse(error: ZodError) {
  return NextResponse.json(
    { error: 'Validation failed', details: error.format() },
    { status: 400 }
  )
}

export function unauthorizedResponse() {
  return errorResponse('Unauthorized', 401)
}

export function forbiddenResponse() {
  return errorResponse('You do not have permission to perform this action', 403)
}

export function notFoundResponse(resource = 'Resource') {
  return errorResponse(`${resource} not found`, 404)
}

export function rateLimitedResponse() {
  return NextResponse.json(
    { error: 'Too many requests. Please try again later.', code: 'RATE_LIMITED' },
    { status: 429 }
  )
}

export function internalErrorResponse() {
  return errorResponse('An unexpected error occurred. Please try again.', 500)
}
```

Every route imports and uses these instead of constructing `NextResponse.json` error bodies ad hoc.

---

## Rule 2 — Global Error Boundaries

### 2.1 — Every API route wrapped in try/catch

No API route handler may let an exception propagate unhandled to the framework's default error page (which can leak stack traces in some configurations). Every handler MUST have a top-level try/catch that logs internally and returns the standard error shape.

```typescript
// src/app/api/v1/bookings/[id]/route.ts
import { NextRequest } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { prisma } from '@/lib/prisma'
import { logger } from '@/lib/logger'
import {
  unauthorizedResponse,
  notFoundResponse,
  forbiddenResponse,
  internalErrorResponse,
} from '@/lib/api-response'
import { NextResponse } from 'next/server'

export async function DELETE(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const session = await getServerSession(authOptions)
    if (!session) return unauthorizedResponse()

    const booking = await prisma.booking.findUnique({
      where: { id: params.id },
      select: { userId: true },
    })

    if (!booking) return notFoundResponse('Booking')
    if (booking.userId !== session.user.id && session.user.role !== 'ADMIN') {
      return forbiddenResponse()
    }

    await prisma.booking.delete({ where: { id: params.id } })
    return NextResponse.json({ success: true })
  } catch (err) {
    logger.error({ err, route: 'DELETE /api/v1/bookings/[id]' }, 'Failed to delete booking')
    return internalErrorResponse()
  }
}
```

### 2.2 — Route-level `error.tsx` for UI routes

Every route segment that renders a server component performing data fetching MUST have a sibling `error.tsx` to catch render-time failures gracefully. See Frontend dimension Rule 5 for the full implementation template — the key requirement here is that no unhandled render error may surface a raw stack trace to the user.

### 2.3 — Root-level catch-all

`src/app/error.tsx` (root) catches anything not caught by a more specific nested `error.tsx`. This is the last line of defense and MUST exist even if every route segment has its own boundary.

### 2.4 — Differentiate expected vs unexpected errors

| Error type | Handling |
|---|---|
| Validation failure (Zod) | Expected — caught explicitly, 400 response, details included |
| Not found | Expected — caught explicitly, 404 response |
| Auth/permission failure | Expected — caught explicitly, 401/403 response |
| Rate limit exceeded | Expected — caught explicitly, 429 response |
| Database connection failure, unexpected exception | Unexpected — caught by top-level try/catch, logged with full context, 500 generic response |

Never let an unexpected error (Prisma connection error, third-party API timeout, null pointer) bubble past the route handler's try/catch.

---

## Rule 3 — Structured Logging (Pino, never `console.log`)

### 3.1 — `console.log`/`console.error`/`console.warn` are prohibited everywhere

In every server-side file (API routes, server components, lib functions, scripts), use the shared `logger` instance. `console.*` calls are not structured, not filterable by level, not redactable, and often leak into production output unfiltered.

```typescript
// ❌ Prohibited anywhere in src/
console.log('User logged in', userId)
console.error(err)

// ✅ Required
logger.info({ userId }, 'User logged in')
logger.error({ err, userId }, 'Login failed')
```

**Exception:** Client-side (`'use client'`) components running in the browser have no access to the server Pino instance. Browser-side debug logging should be removed before shipping, not replaced with `console.log` left in production code. If client-side error reporting is needed, send it to an API route that logs server-side via Pino.

### 3.2 — Logger configuration (recap from Phase 3)

```typescript
// src/lib/logger.ts
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  redact: ['password', 'token', 'secret', 'authorization', 'cookie', '*.password'],
  ...(process.env.NODE_ENV !== 'production' && {
    transport: {
      target: 'pino-pretty',
      options: { colorize: true },
    },
  }),
})
```

### 3.3 — Log level discipline

| Level | Use for |
|---|---|
| `error` | Unhandled exceptions, failed external calls, data integrity issues |
| `warn` | Expected-but-notable conditions (failed login attempt, rate limit hit, deprecated API usage) |
| `info` | Significant business events (user registered, booking created, payment processed) |
| `debug` | Verbose diagnostic detail, off by default in production (`LOG_LEVEL=info`) |

### 3.4 — Always log with context, never log bare strings

```typescript
// ❌ Insufficient — no context to debug with
logger.error('Booking failed')

// ✅ Required — structured context object first, message second
logger.error({ err, userId, restaurantId, attemptedDate: date }, 'Failed to create booking')
```

### 3.5 — Never log sensitive data, even at debug level

Passwords, tokens, full credit card numbers, and session secrets must never appear in any log line — the `redact` configuration is a safety net, not a substitute for not logging them in the first place.

---

## Rule 4 — No Internal Details Exposed to Clients

### 4.1 — Stack traces never leave the server

```typescript
// ❌ Prohibited — leaks file paths, line numbers, internal structure
catch (err) {
  return NextResponse.json({ error: err.message, stack: err.stack }, { status: 500 })
}

// ✅ Required — log internally, return generic message externally
catch (err) {
  logger.error({ err }, 'Unexpected error in booking creation')
  return internalErrorResponse() // { "error": "An unexpected error occurred. Please try again." }
}
```

### 4.2 — Database errors are never passed through

Prisma errors (unique constraint violations, foreign key failures) contain table/column names and constraint identifiers. Translate them to safe, specific messages instead of passing the raw error through.

```typescript
import { Prisma } from '@prisma/client'

try {
  await prisma.user.create({ data: { email, password: hashedPassword } })
} catch (err) {
  if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
    // Unique constraint violation — translate to a safe, specific message
    return errorResponse('An account with this email already exists', 409)
  }
  logger.error({ err }, 'Failed to create user')
  return internalErrorResponse()
}
```

### 4.3 — Third-party API errors are sanitized

When a call to Stripe, Resend, or another third-party service fails, never forward their raw error response to the client — it may contain internal identifiers or implementation details about your integration.

```typescript
try {
  await resend.emails.send({ /* ... */ })
} catch (err) {
  logger.error({ err }, 'Failed to send confirmation email')
  // Don't fail the whole request just because email failed — degrade gracefully
  // Return success for the primary action, log the email failure for follow-up
}
```

### 4.4 — Production vs development verbosity

In development (`NODE_ENV=development`), it is acceptable for the Pino pretty-printer to show full error objects in the terminal — that's server-side, not client-facing. The client-facing JSON response shape from Rule 1 stays identical in every environment. Never branch the API response shape on `NODE_ENV`.

---

## Rule 5 — Correct HTTP Status Codes

### 5.1 — Status code reference

| Situation | Status | Notes |
|---|---|---|
| Success (GET, PATCH, PUT) | 200 | |
| Resource created | 201 | Return the created resource in the body |
| Success, no body to return | 204 | E.g., DELETE success |
| Validation failure | 400 | Include Zod `details` |
| Missing/invalid auth | 401 | Distinguish from 403 — "who are you" vs "you can't do that" |
| Authenticated but not permitted | 403 | Ownership check failures, role check failures |
| Resource doesn't exist | 404 | Never leak whether it exists but belongs to someone else — see 5.2 |
| Conflict (duplicate unique field) | 409 | Email already registered, etc. |
| Validation passes but business rule fails | 422 | E.g., booking a fully-booked time slot |
| Rate limit exceeded | 429 | Include `Retry-After` header |
| Unexpected server failure | 500 | Generic message, full detail logged server-side |
| Dependency unavailable (DB down) | 503 | Used by `/api/health`, can also apply to routes with hard DB dependency |

### 5.2 — 404 vs 403 — avoid resource enumeration leaks

When a resource exists but belongs to another user, prefer returning 404 over 403 in contexts where revealing existence is itself sensitive (e.g., "does this user have a booking with ID X" shouldn't be answerable by an unrelated user). For most internal business apps where the user is at least authenticated, 403 with a generic message is acceptable and clearer for legitimate debugging — document which convention is used per app in `SHIPREADY.md`.

### 5.3 — Never return 200 on failure

A response body containing `{ "error": "..." }` with an HTTP 200 status is a critical anti-pattern — it breaks client error handling that relies on `response.ok`/status codes and is a guaranteed audit deduction.

---

## Deductions reference (Error Handling)

| Violation | Deduction |
|---|---|
| API route returns a non-standard error shape | -1 per route |
| `error: { ... }` body returned with HTTP 200 | -3 per instance |
| Unhandled exception leaks a stack trace to the client | -3 per instance |
| Missing root `error.tsx` | -2 |
| Route segment with data fetching missing `error.tsx` | -1 per segment |
| `console.log`/`console.error` used instead of Pino | -1 per instance |
| Sensitive field (password, token) not in logger redact list | -2 |
| Raw Prisma/database error passed through to client | -2 per instance |
| Wrong HTTP status code for the error class | -1 per instance |
| Missing try/catch in an API route handler | -2 per route |

---

## Checklist (use before scoring)

- [ ] `src/lib/api-response.ts` helpers exist and are used by every route
- [ ] Every API error response matches `{ error, details?, code? }`
- [ ] No route ever returns `{ error: ... }` with a 200 status
- [ ] Every API route handler has a top-level try/catch
- [ ] Root `src/app/error.tsx` exists as a client component
- [ ] Route segments with server-side data fetching have their own `error.tsx` where appropriate
- [ ] No `console.log`, `console.error`, or `console.warn` anywhere in `src/`
- [ ] `logger.ts` redact list includes password, token, secret, authorization, cookie
- [ ] Every `logger.error` call includes a context object, not just a string
- [ ] No stack traces, file paths, or raw error objects in any API response
- [ ] Prisma known errors (e.g., `P2002` unique violation) are translated to safe messages
- [ ] Third-party API failures (email, payment) are logged but don't crash unrelated functionality
- [ ] Correct status codes used: 400 validation, 401 auth, 403 permission, 404 not found, 409 conflict, 422 business rule, 429 rate limit, 500 unexpected, 503 dependency down

---

*Error Handling dimension — shipready v1.0.0*