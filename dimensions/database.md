## Dimension rules (complete)
### Dimension 2 — Database

| Rule | Requirement |
|---|---|
| Error wrapping | Every DB call in `try/catch`. Log with pino. Never swallow errors silently. |
| Singleton | Use the pattern from `src/lib/prisma.ts`. One client per process. No `new PrismaClient()` in route files. |
| Indexes | Index every field used in `WHERE`, `ORDER BY`, or `JOIN`. Use `@@index` in Prisma schema. |
| Seed script | `prisma/seed.ts` with realistic data. At least 3 records per major entity. Admin user included. |
| SQL safety | ORM or parameterized queries. Never `prisma.$queryRaw` with user input. |
| Pagination | Every list endpoint accepts `page` (int, min 1) and `limit` (int, min 1, max 100, default 20). |
| Soft deletes | If the description implies data recovery, add `deletedAt DateTime?` and filter with `where: { deletedAt: null }`. |
| Transactions | Multi-step operations that must be atomic must use `prisma.$transaction([])`. |
| Cascade behavior | Every relation must have explicit `onDelete` — never use implicit defaults. |
| Connection pooling | For serverless (Vercel), configure Prisma Accelerate or `?pgbouncer=true` in DATABASE_URL. |

**Standard schema pattern:**

```prisma
model Resource {
  id          String    @id @default(uuid())
  // ... fields ...
  createdAt   DateTime  @default(now())
  updatedAt   DateTime  @updatedAt
  deletedAt   DateTime? // soft delete

  userId      String
  user        User      @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([createdAt])
  @@map("resources")
}
```

---