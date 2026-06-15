## Dimension rules (complete)

### Dimension 4 — API design

| Rule | Requirement |
|---|---|
| Versioning | All routes under `/api/v1/`. Breaking changes go in `/api/v2/`. |
| RESTful naming | Nouns, plural, lowercase, kebab-case: `/api/v1/user-profiles`, not `/api/v1/getUser`. |
| HTTP methods | GET (read), POST (create), PUT (full update), PATCH (partial update), DELETE (delete). |
| Response shape | Success: `{ data: T, meta?: { page, limit, total } }`. Error: `{ error: string, details?: unknown }`. |
| Pagination | List endpoints: `?page=1&limit=20`. Response includes `meta.total`, `meta.page`, `meta.limit`, `meta.totalPages`. |
| Filtering | List endpoints support `?[field]=[value]` query params for common filter fields. |
| Sorting | List endpoints support `?sortBy=[field]&order=asc|desc`. |
| Idempotency | PUT and DELETE operations must be idempotent. |
| No verbs in URLs | `/api/v1/users/:id/activate` is OK (sub-resource action). `/api/v1/activateUser` is not. |
| Content-Type | All responses: `Content-Type: application/json`. All request bodies must be JSON. |

**Standard pagination response:**

```typescript
// src/lib/pagination.ts
export function paginate<T>(
  data: T[],
  total: number,
  page: number,
  limit: number
) {
  return {
    data,
    meta: {
      total,
      page,
      limit,
      totalPages: Math.ceil(total / limit),
      hasNextPage: page < Math.ceil(total / limit),
      hasPreviousPage: page > 1,
    },
  }
}

export function parsePaginationParams(searchParams: URLSearchParams) {
  const page = Math.max(1, parseInt(searchParams.get('page') ?? '1', 10))
  const limit = Math.min(100, Math.max(1, parseInt(searchParams.get('limit') ?? '20', 10)))
  const skip = (page - 1) * limit
  return { page, limit, skip }
}
```

---
