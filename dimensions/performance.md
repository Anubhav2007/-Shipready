# Performance Dimension — shipready v1.0.0

> **Max points: 15** | This dimension covers database query efficiency, pagination, caching strategy, image optimization, bundle size, and response times. A perfect Performance score means the app serves sub-200ms responses under realistic load, never loads more data than the current view requires, and can handle growth from 10 users to 10,000 without architectural surgery.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| Pagination on all list endpoints and UI | 4 | Any list loads unbounded records |
| Database query efficiency (indexes, N+1 prevention, select fields) | 4 | Full table scans, N+1 queries, `SELECT *` |
| Caching strategy (response headers, ISR, memoization) | 3 | No cache headers, no ISR on public pages |
| Image and asset optimization | 2 | Unoptimized images, no lazy loading |
| Bundle optimization (dynamic imports, code splitting) | 2 | Heavy components loaded eagerly on all routes |

---

## Rule 1 — Pagination (mandatory on every list)

### The absolute rule

**No endpoint or UI component may load an unbounded list of records.** Every query that returns multiple rows MUST be paginated. No exceptions.

Loading a full table into memory is the most common cause of production outages. A table that has 100 rows in development has 100,000 rows in production. `prisma.booking.findMany()` with no `take` or `skip` is a production incident waiting to happen.

### API pagination standard

All list endpoints MUST accept `page` and `limit` query parameters and return a standardized paginated response.

**Required query parameters:**
- `page` — integer ≥ 1, default 1
- `limit` — integer 1–100, default 20

**Required response shape:**
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

**Standard repository pagination function:**
```typescript
// src/lib/bookings.ts
import { prisma } from './prisma'
import { logger } from './logger'

interface PaginationParams {
  page: number
  limit: number
}

export async function listBookings(userId: string, { page, limit }: PaginationParams) {
  const skip = (page - 1) * limit

  // Always run count and data fetch in a transaction to avoid count drift
  const [total, bookings] = await prisma.$transaction([
    prisma.booking.count({
      where: { userId },
    }),
    prisma.booking.findMany({
      where: { userId },
      skip,
      take: limit,
      orderBy: { createdAt: 'desc' },
      select: {
        id: true,
        date: true,
        status: true,
        guestCount: true,
        // Explicitly select only fields needed for the list view
        // Never use select: undefined (which is equivalent to SELECT *)
        restaurant: {
          select: { id: true, name: true, address: true },
        },
      },
    }),
  ])

  return {
    data: bookings,
    pagination: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
      hasNext: skip + limit < total,
      hasPrev: page > 1,
    },
  }
}
```

**Standard API route using pagination:**
```typescript
// src/app/api/v1/bookings/route.ts
import { NextRequest, NextResponse } from 'next/server'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'
import { listBookings } from '@/lib/bookings'
import { z } from 'zod'

const paginationSchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  limit: z.coerce.number().int().min(1).max(100).default(20),
})

export async function GET(request: NextRequest) {
  const session = await getServerSession(authOptions)
  if (!session) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const { searchParams } = request.nextUrl
  const parsed = paginationSchema.safeParse({
    page: searchParams.get('page'),
    limit: searchParams.get('limit'),
  })

  if (!parsed.success) {
    return NextResponse.json(
      { error: 'Invalid pagination parameters', details: parsed.error.format() },
      { status: 400 }
    )
  }

  const result = await listBookings(session.user.id, parsed.data)
  return NextResponse.json(result)
}
```

### Cursor-based pagination (use for high-volume lists)

For lists where the total count is either very large or irrelevant (activity feeds, audit logs, real-time streams), use cursor-based pagination instead of offset:

```typescript
interface CursorPaginationParams {
  cursor?: string   // last item ID from previous page
  limit: number
}

export async function listAuditLogs({ cursor, limit }: CursorPaginationParams) {
  const logs = await prisma.auditLog.findMany({
    take: limit + 1,  // fetch one extra to determine hasNext
    ...(cursor && {
      cursor: { id: cursor },
      skip: 1,  // skip the cursor item itself
    }),
    orderBy: { createdAt: 'desc' },
    select: { id: true, action: true, createdAt: true, userId: true },
  })

  const hasNext = logs.length > limit
  if (hasNext) logs.pop()  // remove the extra item

  return {
    data: logs,
    nextCursor: hasNext ? logs[logs.length - 1].id : null,
    hasNext,
  }
}
```

---

## Rule 2 — Database Query Efficiency

### 2.1 — Indexes (mandatory)

Every field that appears in a `where` clause, `orderBy` clause, or a relation join MUST have a database index defined in `schema.prisma`.

**Decision rule:**
- Single-field queries → `@@index([field])`
- Compound queries used together → `@@index([field1, field2])`
- Unique lookups → `@@unique([field])` (also creates an index)
- Foreign keys → indexed automatically by Prisma when `@relation` is used

**Template — every model with indexes:**
```prisma
model Booking {
  id           String   @id @default(uuid())
  userId       String
  restaurantId String
  date         DateTime
  status       BookingStatus @default(PENDING)
  guestCount   Int
  createdAt    DateTime @default(now())
  updatedAt    DateTime @updatedAt

  user         User       @relation(fields: [userId], references: [id], onDelete: Cascade)
  restaurant   Restaurant @relation(fields: [restaurantId], references: [id], onDelete: Restrict)

  // ── Indexes ───────────────────────────────────────────────────────────────
  @@index([userId])                    // list bookings by user
  @@index([restaurantId])              // list bookings by restaurant
  @@index([date])                      // query by date range
  @@index([status])                    // filter by status
  @@index([userId, status])            // user's bookings filtered by status
  @@index([restaurantId, date])        // restaurant's schedule for a date
}
```

### 2.2 — Preventing N+1 queries

N+1 queries are the most common database performance bug. They occur when fetching a list triggers one query per item to fetch related data.

**Never do this:**
```typescript
// ❌ N+1: 1 query for bookings + 1 query per booking for restaurant
const bookings = await prisma.booking.findMany({ where: { userId } })
const withRestaurants = await Promise.all(
  bookings.map(async (b) => ({
    ...b,
    restaurant: await prisma.restaurant.findUnique({ where: { id: b.restaurantId } }),
  }))
)
```

**Always do this:**
```typescript
// ✅ 1 query with an efficient JOIN
const bookings = await prisma.booking.findMany({
  where: { userId },
  include: {
    restaurant: {
      select: { id: true, name: true, address: true },
    },
  },
})
```

### 2.3 — Explicit `select` (never use implicit `SELECT *`)

**Why:** Selecting all fields transfers unnecessary data over the wire, loads sensitive fields unnecessarily, and prevents the query optimizer from using covering indexes.

**Rule:** Every `findMany`, `findFirst`, and `findUnique` in a repository function MUST use an explicit `select` object.

```typescript
// ❌ Prohibited — implicit SELECT * (Prisma default when no select is specified)
const users = await prisma.user.findMany()

// ✅ Required — explicit field selection
const users = await prisma.user.findMany({
  select: {
    id: true,
    name: true,
    email: true,
    createdAt: true,
    // password, passwordResetToken, and other sensitive fields NOT selected
  },
})
```

**Exception:** When updating or creating records, Prisma's return value can use a narrower select — return only the fields the caller needs.

### 2.4 — Use `$transaction` for related mutations

Any operation that writes to multiple tables MUST be wrapped in a Prisma transaction. Never perform dependent writes sequentially outside a transaction.

```typescript
// ❌ Dangerous — partial failure leaves DB in inconsistent state
await prisma.booking.create({ data: bookingData })
await prisma.notification.create({ data: notificationData })

// ✅ Atomic — both succeed or both fail
const [booking, notification] = await prisma.$transaction([
  prisma.booking.create({ data: bookingData }),
  prisma.notification.create({ data: notificationData }),
])
```

### 2.5 — Never load unbounded relations

Using `include` without `take` on a relation that can have many children is equivalent to a full table scan per parent.

```typescript
// ❌ Loads all reviews for every restaurant — could be thousands
const restaurants = await prisma.restaurant.findMany({
  include: { reviews: true },
})

// ✅ Loads the 5 most recent reviews per restaurant, aggregates the rest
const restaurants = await prisma.restaurant.findMany({
  include: {
    reviews: {
      take: 5,
      orderBy: { createdAt: 'desc' },
      select: { id: true, rating: true, comment: true, createdAt: true },
    },
    _count: { select: { reviews: true } },
  },
})
```

---

## Rule 3 — Caching Strategy

### 3.1 — Next.js fetch caching

Use Next.js's built-in fetch caching for server-side data fetching. Never leave caching to chance.

| Data type | Cache strategy | Next.js option |
|---|---|---|
| Static marketing pages | Cache indefinitely, revalidate on deploy | `cache: 'force-cache'` |
| Semi-static content (restaurant list, public profiles) | Revalidate every 60s (ISR) | `next: { revalidate: 60 }` |
| User-specific data | Never cache (always fresh) | `cache: 'no-store'` |
| Admin data | Never cache | `cache: 'no-store'` |
| Search results | Short TTL (10s) | `next: { revalidate: 10 }` |

```typescript
// Public restaurant listing — ISR, revalidates every 60 seconds
const restaurants = await fetch('/api/v1/restaurants', {
  next: { revalidate: 60 },
})

// User's own bookings — never cached
const bookings = await fetch('/api/v1/bookings', {
  cache: 'no-store',
  headers: { Authorization: `Bearer ${token}` },
})
```

### 3.2 — HTTP cache headers on API routes

API routes that return public, cacheable data MUST set `Cache-Control` headers.

```typescript
// src/app/api/v1/restaurants/route.ts

export async function GET() {
  const restaurants = await listPublicRestaurants({ page: 1, limit: 20 })

  return NextResponse.json(restaurants, {
    headers: {
      // Cache in CDN for 60s, allow stale for 30s while revalidating
      'Cache-Control': 'public, s-maxage=60, stale-while-revalidate=30',
    },
  })
}
```

For authenticated user endpoints, always prevent caching:
```typescript
return NextResponse.json(data, {
  headers: {
    'Cache-Control': 'private, no-cache, no-store, must-revalidate',
  },
})
```

### 3.3 — Memoize expensive repeated reads within a request

Use React's `cache()` function to memoize data fetching functions so multiple server components in the same render tree don't duplicate database queries.

```typescript
// src/lib/queries/session.ts
import { cache } from 'react'
import { getServerSession } from 'next-auth'
import { authOptions } from '@/lib/auth'

// Deduplicated: no matter how many server components call this in one render,
// it executes once and caches the result for the request lifetime.
export const getCurrentUser = cache(async () => {
  const session = await getServerSession(authOptions)
  return session?.user ?? null
})
```

### 3.4 — ISR for public pages

Public-facing pages that don't change per-request MUST use `revalidate`:

```typescript
// src/app/restaurants/page.tsx
// Revalidate every 5 minutes — new restaurants appear within 5 min
export const revalidate = 300

export default async function RestaurantsPage() {
  const restaurants = await getPublicRestaurants({ page: 1, limit: 20 })
  return <RestaurantList restaurants={restaurants} />
}
```

---

## Rule 4 — Image and Asset Optimization

### 4.1 — Always use `next/image`

**Never use `<img>` for user-facing images.** The `next/image` component is mandatory for all images.

```typescript
// ❌ Prohibited
<img src={restaurant.imageUrl} alt={restaurant.name} />

// ✅ Required
import Image from 'next/image'
<Image
  src={restaurant.imageUrl}
  alt={restaurant.name}
  width={400}
  height={300}
  loading="lazy"           // lazy load by default for below-fold images
  placeholder="blur"       // blurred placeholder while loading
  blurDataURL={restaurant.blurHash}
/>

// Above-the-fold images (hero images, LCP candidates) use eager loading:
<Image
  src={heroImage}
  alt="Hero"
  width={1200}
  height={600}
  priority                 // eager load, no lazy
/>
```

### 4.2 — Configure `next.config.ts` for image domains

Every external image domain MUST be allowlisted:

```typescript
// next.config.ts
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'images.unsplash.com',
      },
      {
        protocol: 'https',
        hostname: '*.supabase.co',  // if using Supabase Storage
      },
      // Add all image CDN domains here
    ],
  },
  output: 'standalone',  // required for Dockerfile multi-stage build
}
```

### 4.3 — Lazy load below-fold content

Images that are not visible on initial page load MUST use `loading="lazy"`. The Next.js `Image` component defaults to lazy — do not override this with `loading="eager"` except for above-fold LCP images.

### 4.4 — Avatar and thumbnail constraints

For user avatars and thumbnails, always define explicit size constraints. Avoid loading a 2MB profile photo to render a 40×40px avatar.

```typescript
// Resize on upload or use a dedicated transformation URL
<Image
  src={user.avatarUrl}
  alt={`${user.name} avatar`}
  width={40}
  height={40}
  className="rounded-full object-cover"
/>
```

---

## Rule 5 — Bundle Optimization

### 5.1 — Dynamic imports for heavy components

Components that are heavy, infrequently used, or only needed after a user interaction MUST be dynamically imported.

```typescript
import dynamic from 'next/dynamic'

// Chart libraries are large — don't load them on the initial page render
const BookingChart = dynamic(
  () => import('@/components/charts/BookingChart'),
  {
    loading: () => <Skeleton className="h-64 w-full" />,
    ssr: false,  // disable SSR for browser-only libraries
  }
)

// Rich text editor — only needed when user opens "edit" mode
const RichTextEditor = dynamic(
  () => import('@/components/editor/RichTextEditor'),
  {
    loading: () => <Skeleton className="h-48 w-full" />,
    ssr: false,
  }
)
```

**Always dynamically import:**
- Chart libraries (recharts, chart.js, plotly)
- Rich text editors (Quill, TipTap, Slate)
- Map components (Leaflet, Google Maps)
- Date pickers with large locale bundles
- Any library > 50kb that is not needed for initial render

### 5.2 — `next/font` for custom fonts

Never use `<link>` to load Google Fonts. Use `next/font` for zero layout shift and optimal loading:

```typescript
// src/app/layout.tsx
import { Inter, Roboto_Mono } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
})

const robotoMono = Roboto_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${robotoMono.variable}`}>
      <body>{children}</body>
    </html>
  )
}
```

### 5.3 — Barrel export caution

Avoid deep barrel exports (`index.ts` re-exporting everything from a directory) in large UI libraries. They prevent tree shaking.

```typescript
// ❌ Pulls the entire components/ui/ bundle into every page
import { Button, Input, Modal, Select, Badge, Skeleton } from '@/components/ui'

// ✅ Tree-shakable — only imports what the page needs
import { Button } from '@/components/ui/Button'
import { Input } from '@/components/ui/Input'
```

### 5.4 — Server Components by default

Next.js App Router server components do not add to the JavaScript bundle. Use them by default and only opt into client components when strictly necessary.

**Reasons to add `'use client'`:**
- Uses React hooks (`useState`, `useEffect`, `useRef`, etc.)
- Uses browser APIs (`window`, `document`, `localStorage`)
- Uses event handlers that are interactive
- Uses a library that doesn't support server rendering

**Never add `'use client'` to:**
- Pages that only display static or server-fetched data
- Layout components without interactive elements
- Components that just pass props down

```typescript
// ✅ Server component — no 'use client', no JS bundle contribution
// src/app/(dashboard)/bookings/page.tsx
import { getBookings } from '@/lib/bookings'
import { BookingList } from '@/components/bookings/BookingList'
import { getCurrentUser } from '@/lib/queries/session'

export default async function BookingsPage() {
  const user = await getCurrentUser()
  const bookings = await getBookings(user.id, { page: 1, limit: 20 })
  return <BookingList initialData={bookings} />
}
```

---

## Performance Budgets

Apply these budgets as design constraints, not post-launch aspirations:

| Metric | Target | How shipready achieves it |
|---|---|---|
| API response (GET list) | < 200ms p95 | Indexed queries, pagination, `select` projection |
| API response (POST mutation) | < 500ms p95 | Transactions, no unbounded side effects |
| Time to First Byte (TTFB) | < 200ms | ISR, CDN caching, server components |
| Largest Contentful Paint (LCP) | < 2.5s | `next/image` with priority, font optimization |
| Total Blocking Time (TBT) | < 200ms | Server components, dynamic imports |
| First JS bundle | < 200kb gzipped | Code splitting, dynamic imports |
| Database query (indexed) | < 50ms | Proper indexes on all queried fields |

---

## Deductions reference (Performance)

| Violation | Deduction |
|---|---|
| Any `findMany` without `take` (unbounded) | -4 per instance |
| N+1 query pattern detected | -2 per instance |
| No `@@index` on a field used in a `where` clause | -2 per missing index |
| `<img>` instead of `next/image` | -1 per instance |
| No `Cache-Control` header on a public API endpoint | -1 per endpoint |
| No `revalidate` on a public page | -1 per page |
| Heavy library imported eagerly (chart, map, editor) | -1 per library |
| `SELECT *` via implicit Prisma select | -2 per query |
| Unbounded `include` on a to-many relation | -2 per relation |
| Multiple server components duplicating the same DB query | -1 per duplicate |
| Fonts loaded via `<link>` instead of `next/font` | -1 |

---

## Checklist (use before scoring)

- [ ] Every `findMany` call has an explicit `take` parameter
- [ ] All list API endpoints accept and validate `page` and `limit` parameters
- [ ] All list API endpoints return the standard `{ data, pagination }` shape
- [ ] All `findMany` calls use explicit `select` — no implicit `SELECT *`
- [ ] Every field used in a `where` clause has a `@@index` in schema.prisma
- [ ] Every field used in an `orderBy` has a `@@index` in schema.prisma
- [ ] No N+1 patterns — related data fetched with `include` or `select`, not in a loop
- [ ] All multi-table mutations use `prisma.$transaction`
- [ ] Unbounded `include` on to-many relations has a `take` limit
- [ ] Public API endpoints have `Cache-Control` headers
- [ ] User-specific API endpoints have `Cache-Control: private, no-store`
- [ ] Public pages use `export const revalidate`
- [ ] `getCurrentUser` and other repeated reads use React `cache()`
- [ ] All images use `next/image` with explicit `width` and `height`
- [ ] Hero / above-fold images use `priority` prop
- [ ] Chart, map, and editor libraries use `dynamic()` imports
- [ ] Custom fonts use `next/font` instead of `<link>`
- [ ] Page components are server components by default (no unnecessary `'use client'`)
- [ ] `next.config.ts` has `output: 'standalone'` and `images.remotePatterns` configured

---

*Performance dimension — shipready v1.0.0*