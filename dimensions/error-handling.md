## Dimension rules (complete)
### Dimension 3 — Error handling

| Rule | Requirement |
|---|---|
| API error shape | Every error response: `{ error: "ERROR_CODE", message?: "...", details?: {...} }` |
| HTTP codes | 200 OK, 201 Created, 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict, 422 Unprocessable Entity, 429 Too Many Requests, 500 Internal Server Error |
| No stack traces | Never expose stack traces in API responses or UI error messages. Log internally with Pino. |
| Global boundary | `src/app/error.tsx` — catches React render errors. Shows user-friendly message. |
| 404 page | `src/app/not-found.tsx` — with navigation back to home. |
| Form states | Every form: loading (disabled + spinner), error (field-level + form-level), success (message or redirect). |
| Empty states | Every list component: show "No [items] found" with an action CTA when the list is empty. |
| Logging | All errors logged with Pino including context (userId, resourceId, endpoint). |

**Standard error codes:**

```typescript
// src/lib/errors.ts
export const ErrorCodes = {
  VALIDATION_ERROR: 'VALIDATION_ERROR',
  UNAUTHORIZED: 'UNAUTHORIZED',
  FORBIDDEN: 'FORBIDDEN',
  NOT_FOUND: 'NOT_FOUND',
  CONFLICT: 'CONFLICT',
  TOO_MANY_REQUESTS: 'TOO_MANY_REQUESTS',
  INTERNAL_SERVER_ERROR: 'INTERNAL_SERVER_ERROR',
} as const

export type ErrorCode = keyof typeof ErrorCodes

export function errorResponse(
  code: ErrorCode,
  status: number,
  details?: unknown
) {
  return Response.json({ error: code, details }, { status })
}
```

---