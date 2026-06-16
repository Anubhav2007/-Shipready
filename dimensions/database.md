# Database Dimension — shipready v1.0.0

> **Max points: 15** | This dimension covers schema design, indexing, migrations, seed data, and connection safety. A perfect Database score means the schema models every entity correctly, every queried field is indexed, every relation has explicit delete behavior, and a fresh clone can be seeded with realistic data in one command.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| Schema completeness (all entities, fields, relations) | 4 | Missing entities implied by description, no relations |
| Indexes on all queried/sorted fields | 3 | Any `where`/`orderBy` field unindexed |
| Explicit `onDelete` behavior on every relation | 2 | Any relation missing `onDelete` |
| Migrations (proper, not `db push`) | 2 | Using `prisma db push` instead of migrations in production flow |
| Seed data (realistic, ≥3 records/entity) | 2 | Missing seed file or trivial/empty seed |
| Connection safety (singleton pattern) | 2 | New `PrismaClient()` instantiated per request |

---

## Rule 1 — Schema Completeness

### 1.1 — Every model requires these base fields

```prisma
model Example {
  id        String   @id @default(uuid())
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  // ...entity-specific fields
}
```

- `id` — always `String @id @default(uuid())`. Never auto-incrementing integers for primary keys (UUIDs prevent enumeration attacks and simplify distributed systems).
- `createdAt` — always present, always `@default(now())`.
- `updatedAt` — always present, always `@updatedAt` (Prisma auto-manages this).

### 1.2 — Entity extraction from description

Before writing schema, extract every entity the description implies, including implicit ones:

| Description mentions | Explicit entities | Implicit entities required |
|---|---|---|
| "restaurant booking with admin panel" | Restaurant, Booking | User, Session (NextAuth), Table/Slot (if capacity matters) |
| "e-commerce store with Stripe checkout" | Product, Order | User, Cart, CartItem, OrderItem, Address |
| "SaaS waitlist with referral tracking" | WaitlistEntry | User (if accounts exist), ReferralCode |
| "project management tool like Trello" | Board, List, Card | User, BoardMember, Comment, Activity |
| "blog/CMS" | Post, Category | User (Author), Tag, PostTag (join table) |

**Never ship a schema missing an entity the description implies**, even implicitly. "Admin panel" implies a `role` field on `User` at minimum. "Reviews" implies a `Review` model with a relation to both `User` and the reviewed entity.

### 1.3 — NextAuth required models (when auth is included)

```prisma
model User {
  id            String    @id @default(uuid())
  name          String?
  email         String    @unique
  emailVerified DateTime?
  password      String?   // null if OAuth-only
  image         String?
  role          Role      @default(USER)
  createdAt     DateTime  @default(now())
  updatedAt     DateTime  @updatedAt

  accounts      Account[]
  sessions      Session[]
  // ...other relations (bookings, orders, posts, etc.)

  @@index([email])
}

model Account {
  id                String  @id @default(uuid())
  userId            String
  type              String
  provider          String
  providerAccountId String
  refresh_token     String? @db.Text
  access_token      String? @db.Text
  expires_at        Int?
  token_type        String?
  scope             String?
  id_token          String? @db.Text
  session_state     String?

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([provider, providerAccountId])
  @@index([userId])
}

model Session {
  id           String   @id @default(uuid())
  sessionToken String   @unique
  userId       String
  expires      DateTime

  user User @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
}

model VerificationToken {
  identifier String
  token      String   @unique
  expires    DateTime

  @@unique([identifier, token])
}

enum Role {
  USER
  ADMIN
}
```

### 1.4 — Enums over free-text status fields

Any field representing a fixed set of states (status, role, type, tier) MUST be a Prisma `enum`, never a free-text `String`.

```prisma
// ❌ Prohibited — no validation, typos create invalid states
model Booking {
  status String // "pending", "Pending", "PENDING" all possible — data integrity bug
}

// ✅ Required
enum BookingStatus {
  PENDING
  CONFIRMED
  CANCELLED
  COMPLETED
}

model Booking {
  status BookingStatus @default(PENDING)
}
```

### 1.5 — Join tables for many-to-many relations

Never model many-to-many with implicit Prisma relations when the relationship itself carries data (timestamps, roles, status). Use an explicit join model.

```prisma
// Use implicit many-to-many only for simple tagging with no extra data:
model Post {
  tags Tag[]
}
model Tag {
  posts Post[]
}

// Use explicit join model when the relationship has its own attributes:
model BoardMember {
  id       String   @id @default(uuid())
  boardId  String
  userId   String
  role     MemberRole @default(MEMBER)
  joinedAt DateTime   @default(now())

  board Board @relation(fields: [boardId], references: [id], onDelete: Cascade)
  user  User  @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([boardId, userId])
  @@index([boardId])
  @@index([userId])
}
```

---

## Rule 2 — Indexing

### 2.1 — Index every field used in `where`, `orderBy`, or as a foreign key

This is the single most common cause of production slowdowns as data grows. Apply this rule mechanically: for every repository function written in Phase 4, cross-reference its `where` and `orderBy` clauses against the schema and add missing indexes.

```prisma
model Booking {
  id           String        @id @default(uuid())
  userId       String
  restaurantId String
  date         DateTime
  status       BookingStatus @default(PENDING)
  createdAt    DateTime      @default(now())
  updatedAt    DateTime      @updatedAt

  user       User       @relation(fields: [userId], references: [id], onDelete: Cascade)
  restaurant Restaurant @relation(fields: [restaurantId], references: [id], onDelete: Restrict)

  @@index([userId])               // WHERE userId = ?
  @@index([restaurantId])         // WHERE restaurantId = ?
  @@index([date])                 // WHERE date BETWEEN ? AND ?, ORDER BY date
  @@index([status])               // WHERE status = ?
  @@index([userId, status])       // WHERE userId = ? AND status = ? (compound)
  @@index([restaurantId, date])   // restaurant's schedule for a date range
}
```

### 2.2 — Compound index field order matters

In a compound index `@@index([a, b])`, queries filtering on `a` alone or on `a AND b` use the index. Queries filtering on `b` alone do NOT use this index. Order fields by: (1) fields always present in the query, (2) equality filters before range filters, (3) highest cardinality first among equality filters.

### 2.3 — Unique constraints double as indexes

Don't add a redundant `@@index` for a field already covered by `@unique` or `@@unique` — Prisma/PostgreSQL automatically indexes unique constraints.

### 2.4 — Full-text search fields

If the description implies search ("search restaurants", "find products"), add a dedicated index strategy:

```prisma
model Restaurant {
  id      String @id @default(uuid())
  name    String
  cuisine String

  @@index([name])     // basic prefix search support
  @@index([cuisine])  // filter by cuisine
}
```

For production-grade full-text search beyond simple prefix matching, document in `SHIPREADY.md` that PostgreSQL's `tsvector`/`tsquery` or a dedicated search service (Algolia, Meilisearch) should be added — this is an acceptable documented limitation, not a placeholder.

---

## Rule 3 — Explicit `onDelete` Behavior

### 3.1 — Every relation MUST declare `onDelete`

Never leave `onDelete` to Prisma's default (which throws a restrict-like error in practice but is implicit and undocumented). Every `@relation` MUST explicitly state its delete behavior.

| Behavior | When to use |
|---|---|
| `Cascade` | Child record has no meaning without the parent (e.g., `Account`/`Session` without `User`; `OrderItem` without `Order`) |
| `Restrict` | Deleting the parent should be blocked while children exist (e.g., can't delete a `Restaurant` with active `Booking`s) |
| `SetNull` | Child can survive parent deletion in an orphaned-but-valid state (e.g., `Post.authorId` when the author account is deleted, but posts remain) |

```prisma
model Booking {
  userId       String
  restaurantId String

  // User deletion cascades to their bookings — bookings are meaningless without the user
  user       User       @relation(fields: [userId], references: [id], onDelete: Cascade)

  // Restaurant deletion is blocked while bookings exist — protects business data integrity
  restaurant Restaurant @relation(fields: [restaurantId], references: [id], onDelete: Restrict)
}

model Post {
  authorId String?

  // Author account deletion sets authorId to null — post content is preserved
  author User? @relation(fields: [authorId], references: [id], onDelete: SetNull)
}
```

### 3.2 — Document the decision

Every non-obvious `onDelete` choice should be documented in `SHIPREADY.md` under "Decisions made on your behalf" — e.g., "Restaurant deletion uses Restrict to prevent orphaned booking history; admins must cancel/archive bookings first."

---

## Rule 4 — Migrations

### 4.1 — `prisma migrate`, never `db push`, for shipped code

`prisma db push` is a prototyping tool that skips migration history. shipready-generated apps MUST use `prisma migrate dev` during generation and `prisma migrate deploy` for production. This produces a versioned `prisma/migrations/` directory that is part of the deliverable.

```bash
# Generation time (creates migration file + applies it)
npx prisma migrate dev --name init

# Production deployment (applies pending migrations, no schema drift detection prompts)
npx prisma migrate deploy
```

### 4.2 — Migration directory is committed

`prisma/migrations/` MUST be committed to version control (do not add it to `.gitignore`). Migration history is part of the deliverable — it documents how the schema evolved and allows safe production deploys.

### 4.3 — One logical change per migration

When the schema evolves during generation (e.g., adding a feature after the initial schema), generate a new named migration rather than editing the initial one:

```bash
npx prisma migrate dev --name add_reviews_table
```

### 4.4 — README documents the migration command

The Setup section of `README.md` must show the exact migration command (see DevOps dimension Rule 4) — `npx prisma migrate dev --name init` for first-time local setup, `npx prisma migrate deploy` for production/CI.

---

## Rule 5 — Seed Data

### 5.1 — Minimum requirements

- At least 3 realistic records per major entity.
- One seeded admin account with documented credentials (see Security dimension Rule 1 for hashing requirements — never seed a plaintext password into the database).
- Seed data must reflect realistic relationships (a seeded `Booking` must reference real seeded `User` and `Restaurant` IDs, not orphaned references).
- Idempotent: running `prisma db seed` twice should not create duplicates or crash. Use `upsert` instead of `create`.

### 5.2 — Standard seed file

```typescript
// prisma/seed.ts
import { PrismaClient } from '@prisma/client'
import bcrypt from 'bcrypt'

const prisma = new PrismaClient()

async function main() {
  const adminPassword = await bcrypt.hash('Admin1234!', 12)
  const userPassword = await bcrypt.hash('User1234!', 12)

  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {},
    create: {
      email: 'admin@example.com',
      name: 'Admin User',
      password: adminPassword,
      role: 'ADMIN',
      emailVerified: new Date(),
    },
  })

  const user1 = await prisma.user.upsert({
    where: { email: 'user1@example.com' },
    update: {},
    create: {
      email: 'user1@example.com',
      name: 'Alice Johnson',
      password: userPassword,
      role: 'USER',
      emailVerified: new Date(),
    },
  })

  const user2 = await prisma.user.upsert({
    where: { email: 'user2@example.com' },
    update: {},
    create: {
      email: 'user2@example.com',
      name: 'Bob Smith',
      password: userPassword,
      role: 'USER',
      emailVerified: new Date(),
    },
  })

  const restaurant1 = await prisma.restaurant.upsert({
    where: { id: 'seed-restaurant-1' },
    update: {},
    create: {
      id: 'seed-restaurant-1',
      name: 'The Golden Spoon',
      cuisine: 'Italian',
      address: '123 Main St, Springfield',
      capacity: 40,
    },
  })

  const restaurant2 = await prisma.restaurant.upsert({
    where: { id: 'seed-restaurant-2' },
    update: {},
    create: {
      id: 'seed-restaurant-2',
      name: 'Sakura Sushi',
      cuisine: 'Japanese',
      address: '456 Oak Ave, Springfield',
      capacity: 25,
    },
  })

  await prisma.booking.upsert({
    where: { id: 'seed-booking-1' },
    update: {},
    create: {
      id: 'seed-booking-1',
      userId: user1.id,
      restaurantId: restaurant1.id,
      date: new Date(Date.now() + 86400000 * 2),
      guestCount: 4,
      status: 'CONFIRMED',
    },
  })

  await prisma.booking.upsert({
    where: { id: 'seed-booking-2' },
    update: {},
    create: {
      id: 'seed-booking-2',
      userId: user2.id,
      restaurantId: restaurant2.id,
      date: new Date(Date.now() + 86400000 * 5),
      guestCount: 2,
      status: 'PENDING',
    },
  })

  console.log('✅ Seed complete')
  console.log(`   Admin: admin@example.com / Admin1234!`)
  console.log(`   User:  user1@example.com / User1234!`)
}

main()
  .catch((e) => {
    console.error('❌ Seed failed:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
```

### 5.3 — Register the seed script

```json
// package.json
{
  "prisma": {
    "seed": "tsx prisma/seed.ts"
  }
}
```

---

## Rule 6 — Connection Safety (Singleton Pattern)

### 6.1 — Never instantiate `PrismaClient` per request

In serverless and hot-reload development environments, creating a new `PrismaClient` per request/module-load exhausts the database's connection pool within minutes. This is a guaranteed production incident.

```typescript
// ❌ Prohibited — new connection pool created on every import in dev (hot reload)
// somewhere in an API route:
const prisma = new PrismaClient()

// ✅ Required — singleton, reused across hot reloads in dev and across
// invocations within the same serverless instance in production
// src/lib/prisma.ts
import { PrismaClient } from '@prisma/client'
import { logger } from './logger'

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: [
      { emit: 'event', level: 'query' },
      { emit: 'event', level: 'error' },
      { emit: 'event', level: 'warn' },
    ],
  })

prisma.$on('error', (e) => {
  logger.error({ err: e }, 'Prisma error')
})

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma
}
```

Every repository function and route handler imports this single instance:
```typescript
import { prisma } from '@/lib/prisma'
```

### 6.2 — Connection pool sizing for serverless

When deploying to Vercel (serverless), the `DATABASE_URL` MUST include connection pool limits to prevent exhausting Postgres's max connections across concurrent function invocations. Document this in `.env.example`:

```bash
# For serverless deployments (Vercel), append connection_limit to avoid pool exhaustion.
# Use a pooler (Prisma Accelerate, PgBouncer, or Supabase's pooler) in production.
DATABASE_URL="postgresql://user:password@localhost:5432/dbname?connection_limit=5&pool_timeout=10"
```

### 6.3 — Graceful disconnect in scripts

Standalone scripts (seed, migration helpers) MUST call `prisma.$disconnect()` in a `finally` block — see the seed file template in Rule 5.2.

---

## Deductions reference (Database)

| Violation | Deduction |
|---|---|
| Entity implied by description but missing from schema | -3 per entity |
| Status/role/type field as `String` instead of `enum` | -1 per field |
| Field used in `where`/`orderBy` without `@@index` | -2 per field |
| Relation missing explicit `onDelete` | -2 per relation |
| `prisma db push` used instead of `prisma migrate` | -3 |
| `prisma/migrations/` missing or gitignored | -2 |
| Seed file missing | -2 |
| Seed file has fewer than 3 records for a major entity | -1 per entity |
| Seed script not idempotent (`create` instead of `upsert`) | -1 |
| Seeded password stored in plaintext | -5 (Security cross-deduction) |
| `new PrismaClient()` instantiated outside the singleton file | -3 per instance |
| Auto-incrementing integer used as primary key instead of UUID | -1 per model |

---

## Checklist (use before scoring)

- [ ] Every entity implied by the description (explicit and implicit) is modeled
- [ ] Every model has `id` (UUID), `createdAt`, `updatedAt`
- [ ] NextAuth models (`User`, `Account`, `Session`, `VerificationToken`) present if auth is included
- [ ] All status/role/type fields use `enum`, not free-text `String`
- [ ] Every field used in a `where` or `orderBy` clause has `@@index`
- [ ] Compound indexes added for common multi-field query patterns
- [ ] Every `@relation` has an explicit `onDelete` (`Cascade`, `Restrict`, or `SetNull`)
- [ ] Non-obvious `onDelete` choices documented in `SHIPREADY.md`
- [ ] `prisma migrate dev --name init` used to generate the initial migration
- [ ] `prisma/migrations/` is committed, not gitignored
- [ ] `prisma/seed.ts` exists with ≥3 records per major entity
- [ ] Seed script uses `upsert`, runs idempotently
- [ ] Seed admin password is hashed with bcrypt before storage
- [ ] `src/lib/prisma.ts` singleton pattern used everywhere — no other `new PrismaClient()`
- [ ] `.env.example` documents connection pool limits for serverless deployment

---

*Database dimension — shipready v1.0.0*