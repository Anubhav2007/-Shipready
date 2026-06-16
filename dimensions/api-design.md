# API Design Dimension — shipready v1.0.0

> **Max points: 10** | This dimension covers RESTful conventions, versioning, HTTP semantics, request/response consistency, and pagination contracts. A perfect API Design score means the API is predictable enough that a developer who has never seen the codebase can guess the next endpoint's shape correctly.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| RESTful resource conventions | 3 | Verbs in URLs, inconsistent pluralization, non-resource-based routes |
| Versioning (`/api/v1/`) | 1 | Missing version prefix |
| HTTP method semantics | 2 | GET with side effects, POST used for reads, wrong idempotency |
| Consistent request/response shapes | 2 | Different shapes for similar resources |
| Pagination contract on collection endpoints | 2 | Missing or inconsistent pagination params/response |

---

## Rule 1 — RESTful Resource Conventions

### 1.1 — URLs are nouns, not verbs

Every endpoint represents a resource (a noun), and the HTTP method represents the action. Never encode the action into the URL path.

```
❌ POST /api/v1/createBooking
❌ POST /api/v1/bookings/cancel
❌ GET  /api/v1/getUserBookings

✅ POST   /api/v1/bookings
✅ PATCH  /api/v1/bookings/:id        (body: { status: "CANCELLED" })
✅ GET    /api/v1/users/:id/bookings
```

**Exception:** Non-CRUD actions that don't map cleanly to a resource state change (e.g., "send a password reset email", "verify an email token") may use a verb sub-resource, but sparingly:
```
✅ POST /api/v1/auth/forgot-password
✅ POST /api/v1/auth/verify-email
```

### 1.2 — Plural nouns for collections, consistently

Every resource collection uses a plural noun. Never mix singular and plural across the same API.

```
✅ /api/v1/bookings
✅ /api/v1/bookings/:id
✅ /api/v1/restaurants
✅ /api/v1/restaurants/:id/reviews

❌ /api/v1/booking          (singular collection)
❌ /api/v1/restaurant/:id   (singular when bookings/ uses plural)
```

### 1.3 — Nested resources for ownership/containment

When a resource is logically owned by or scoped to a parent, nest it under the parent's path — but cap nesting at two levels for readability.

```
✅ GET  /api/v1/restaurants/:restaurantId/reviews
✅ POST /api/v1/restaurants/:restaurantId/reviews
✅ GET  /api/v1/restaurants/:restaurantId/reviews/:reviewId

❌ /api/v1/restaurants/:id/reviews/:reviewId/replies/:replyId/likes  (too deep — flatten)
✅ /api/v1/replies/:replyId/likes   (flatten beyond 2 levels, reference parent via body/query instead)
```

### 1.4 — Standard CRUD mapping

For every entity with a full CRUD surface (per Phase 4.3 of the main skill), the mapping is fixed:

| Action | Method | Path | Success status |
|---|---|---|---|
| List | `GET` | `/api/v1/bookings` | 200 |
| Create | `POST` | `/api/v1/bookings` | 201 |
| Read one | `GET` | `/api/v1/bookings/:id` | 200 |
| Update (partial) | `PATCH` | `/api/v1/bookings/:id` | 200 |
| Replace (full) | `PUT` | `/api/v1/bookings/:id` | 200 |
| Delete | `DELETE` | `/api/v1/bookings/:id` | 200 or 204 |

Prefer `PATCH` over `PUT` for typical update forms (partial field updates are the common case). Only implement `PUT` if the description implies full-resource replacement semantics.

---

## Rule 2 — Versioning

### 2.1 — `/api/v1/` prefix is mandatory on every business-logic route

Every resource route MUST live under `/api/v1/`. This is non-negotiable even for a brand-new app with no prior version — it costs nothing now and prevents a breaking migration later.

```
✅ /api/v1/bookings
✅ /api/v1/restaurants
✅ /api/v1/users/:id

❌ /api/bookings        (no version)
❌ /api/v1/bookings/v2  (version belongs at the root, not nested)
```

### 2.2 — Exemptions from versioning

Framework-required and infrastructure routes are NOT versioned, since they are not part of the business API surface:

```
/api/auth/[...nextauth]   — NextAuth's required route shape
/api/health               — infrastructure, not a business resource
```

### 2.3 — Breaking changes get a new version, not a flag

If a future change to an endpoint's request/response shape would break existing clients, it ships as `/api/v2/[resource]`, with `/api/v1/` continuing to function until deprecated. Never silently change a v1 response shape — document any such future consideration in `SHIPREADY.md` rather than doing it preemptively.

---

## Rule 3 — HTTP Method Semantics

### 3.1 — Method-to-semantics mapping (must be followed exactly)

| Method | Idempotent? | Has side effects? | Use for |
|---|---|---|---|
| `GET` | Yes | No | Reading data only. Never mutate state in a GET handler. |
| `POST` | No | Yes | Creating a resource, or a non-idempotent action (login, send email) |
| `PUT` | Yes | Yes | Full replacement of a resource — calling it twice with the same body yields the same end state |
| `PATCH` | No (by convention, treat as not guaranteed) | Yes | Partial update of a resource |
| `DELETE` | Yes | Yes | Removing a resource — calling it twice yields the same end state (already deleted) |

### 3.2 — GET must never have side effects

```typescript
// ❌ Prohibited — GET handler that mutates state (increments a counter, marks as read)
export async function GET(request: NextRequest, { params }: { params: { id: string } }) {
  await prisma.notification.update({ where: { id: params.id }, data: { read: true } })
  return NextResponse.json(notification)
}

// ✅ Required — reading "marks as read" is a distinct, explicit action
export async function PATCH(request: NextRequest, { params }: { params: { id: string } }) {
  const notification = await prisma.notification.update({
    where: { id: params.id },
    data: { read: true },
  })
  return NextResponse.json(notification)
}
```

This matters beyond style: GET requests can be prefetched, cached, retried automatically by browsers/CDNs, and crawled by bots. A GET with side effects creates unpredictable, hard-to-debug behavior.

### 3.3 — Query parameters for filtering/sorting/pagination, never for actions

```
✅ GET /api/v1/bookings?status=CONFIRMED&page=2&limit=20&sort=date:desc
❌ GET /api/v1/bookings?action=cancel&id=123
```

---

## Rule 4 — Consistent Request/Response Shapes

### 4.1 — Success response shape

| Scenario | Shape |
|---|---|
| Single resource | The resource object directly: `{ "id": "...", "name": "...", ... }` |
| Collection | `{ "data": [...], "pagination": { ... } }` — see Rule 5 |
| Action with no resource to return | `{ "success": true }` |

Never wrap a single resource in an arbitrary envelope inconsistently — if one single-resource endpoint returns the object directly, all single-resource endpoints do.

```typescript
// ✅ Single resource — returned directly
{
  "id": "a1b2c3",
  "date": "2025-02-01T19:00:00.000Z",
  "status": "CONFIRMED",
  "restaurant": { "id": "x1", "name": "The Golden Spoon" }
}

// ✅ Collection — wrapped with pagination metadata
{
  "data": [ { "id": "a1b2c3", ... }, { "id": "d4e5f6", ... } ],
  "pagination": { "page": 1, "limit": 20, "total": 47, "totalPages": 3, "hasNext": true, "hasPrev": false }
}
```

### 4.2 — Error response shape

See Error Handling dimension Rule 1 for the canonical `{ error, details?, code? }` shape — API Design and Error Handling jointly enforce this; it is scored under Error Handling but the consistency requirement originates here.

### 4.3 — Date/time format

All dates and timestamps in request and response bodies MUST use ISO 8601 (`YYYY-MM-DDTHH:mm:ss.sssZ`), always UTC. Never use locale-specific or ambiguous formats (`MM/DD/YYYY`).

### 4.4 — Field naming convention

All JSON field names use `camelCase`, matching the Prisma schema and TypeScript conventions, consistently across every endpoint. Never mix `snake_case` and `camelCase` within the same API.

### 4.5 — Nested relation shape consistency

When an endpoint includes a related resource, the shape of that nested object MUST match the shape returned when that resource is fetched directly (same field names, same casing), even if a subset of fields is selected for the nested case.

```typescript
// Restaurant fetched directly:
{ "id": "x1", "name": "The Golden Spoon", "cuisine": "Italian", "address": "...", "capacity": 40 }

// Restaurant nested inside a booking response — subset of fields, same naming:
{
  "id": "a1b2c3",
  "restaurant": { "id": "x1", "name": "The Golden Spoon", "address": "..." }
  // not: { "restaurantId": "x1", "restaurantName": "...", "restaurant_address": "..." }
}
```

---

## Rule 5 — Pagination Contract

### 5.1 — Standard request parameters

Every collection endpoint accepts:
- `page` (integer, ≥1, default 1)
- `limit` (integer, 1–100, default 20)

Optional, when applicable to the resource:
- `sort` (format: `field:asc` or `field:desc`)
- Resource-specific filters as additional query params (`status`, `cuisine`, `dateFrom`, `dateTo`, etc.)

### 5.2 — Standard response shape

```typescript
interface PaginatedResponse<T> {
  data: T[]
  pagination: {
    page: number
    limit: number
    total: number
    totalPages: number
    hasNext: boolean
    hasPrev: boolean
  }
}
```

This exact shape is used on every collection endpoint with zero variation. See Performance dimension Rule 1 for the full implementation pattern (query logic, transaction-wrapped count, repository function template) — API Design's role is to enforce that the contract above is what every endpoint exposes regardless of the underlying resource.

### 5.3 — Validate pagination params, never trust raw query strings

```typescript
import { z } from 'zod'

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
})
```

A request for `limit=10000` must be clamped/rejected by this schema (max 100), not passed through to the database query — see Performance Rule 1 for why unbounded limits are dangerous.

### 5.4 — Cursor pagination is an explicit alternative, not a silent variant

If a specific endpoint uses cursor-based pagination instead of offset (per Performance dimension Rule 1's cursor pattern for high-volume lists), its response shape differs intentionally:

```typescript
interface CursorPaginatedResponse<T> {
  data: T[]
  nextCursor: string | null
  hasNext: boolean
}
```

This must be documented explicitly in the README API reference for that specific endpoint — never mix offset and cursor pagination shapes across different pages of the same logical resource.

---

## Standard Route Handler Template (reference implementation)

This template demonstrates Rules 1–5 working together in one file:

```typescript
// src/app/api/v1/bookings/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { createBookingSchema } from '@/lib/validations/booking'
import { listBookings, createBooking } from '@/lib/bookings'
import { apiRateLimit } from '@/lib/rate-limit'
import { logger } from '@/lib/logger'
import {
  unauthorizedResponse,
  validationErrorResponse,
  rateLimitedResponse,
  internalErrorResponse,
} from '@/lib/api-response'
import { z } from 'zod'

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
  status: z.enum(['PENDING', 'CONFIRMED', 'CANCELLED', 'COMPLETED']).optional(),
})

// GET /api/v1/bookings — list, paginated, no side effects
export async function GET(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session) return unauthorizedResponse()

    const { success } = await apiRateLimit.limit(session.user.id)
    if (!success) return rateLimitedResponse()

    const { searchParams } = request.nextUrl
    const parsed = paginationSchema.safeParse({
      page: searchParams.get('page'),
      limit: searchParams.get('limit'),
      status: searchParams.get('status') ?? undefined,
    })
    if (!parsed.success) return validationErrorResponse(parsed.error)

    const result = await listBookings(session.user.id, parsed.data)
    return NextResponse.json(result, {
      headers: { 'Cache-Control': 'private, no-cache, no-store, must-revalidate' },
    })
  } catch (err) {
    logger.error({ err }, 'Failed to list bookings')
    return internalErrorResponse()
  }
}

// POST /api/v1/bookings — create, returns 201 with the created resource
export async function POST(request: NextRequest) {
  try {
    const session = await getServerSession(authOptions)
    if (!session) return unauthorizedResponse()

    const { success } = await apiRateLimit.limit(session.user.id)
    if (!success) return rateLimitedResponse()

    const body = await request.json()
    const parsed = createBookingSchema.safeParse(body)
    if (!parsed.success) return validationErrorResponse(parsed.error)

    const booking = await createBooking(session.user.id, parsed.data)
    return NextResponse.json(booking, { status: 201 })
  } catch (err) {
    logger.error({ err }, 'Failed to create booking')
    return internalErrorResponse()
  }
}
```

---

## Deductions reference (API Design)

| Violation | Deduction |
|---|---|
| Verb in URL path instead of noun + HTTP method | -2 per route |
| Inconsistent pluralization across resources | -1 per resource |
| Missing `/api/v1/` prefix on a business route | -1 per route |
| GET handler with a side effect (mutation) | -3 per instance |
| Wrong success status code (e.g., 200 on create instead of 201) | -1 per instance |
| Inconsistent response envelope across similar endpoints | -2 |
| Mixed `camelCase`/`snake_case` field naming | -1 per instance |
| Collection endpoint missing pagination params | -2 per endpoint |
| Pagination response missing any required field (`hasNext`, `totalPages`, etc.) | -1 per missing field |
| Non-ISO 8601 date format in any response | -1 per instance |
| Nesting resources more than 2 levels deep | -1 |

---

## Checklist (use before scoring)

- [ ] Every endpoint uses a noun-based path; actions are expressed via HTTP method
- [ ] All collection paths use plural nouns consistently
- [ ] Resource nesting never exceeds 2 levels
- [ ] Every business route is prefixed with `/api/v1/`
- [ ] `GET` handlers never mutate state
- [ ] `POST` returns 201 with the created resource on success
- [ ] `DELETE` returns 200 or 204
- [ ] `PATCH` used for partial updates; `PUT` only when full-replacement semantics apply
- [ ] Single-resource responses return the object directly (no inconsistent envelope)
- [ ] Collection responses use `{ data, pagination }` shape with all required pagination fields
- [ ] All field names are `camelCase` throughout the entire API
- [ ] All dates/timestamps are ISO 8601 UTC
- [ ] Nested relation objects use the same field names/casing as their top-level counterparts
- [ ] Every collection endpoint validates `page`/`limit` with Zod and clamps `limit` to ≤100
- [ ] Any cursor-paginated endpoint is documented explicitly as a deviation from the offset standard

---

*API Design dimension — shipready v1.0.0*