# Environment Dimension — shipready v1.0.0

> **Max points: 10** | This dimension covers startup validation, `.env.example` completeness, per-environment configuration, and the absolute prohibition on hardcoded values. A perfect Environment score means the app fails fast with a clear error message if misconfigured, and a developer can find every required variable in one file with no guesswork.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| Startup validation (Zod env schema) | 4 | Missing validation, app starts with invalid config and fails later/silently |
| `.env.example` completeness | 3 | Missing variables, no comments, real values present |
| Per-environment configuration | 2 | No distinction between dev/test/production behavior |
| No hardcoded values anywhere | 1 | Any URL, key, or config value hardcoded in source |

---

## Rule 1 — Startup Validation (Zod env schema)

### 1.1 — Every app validates its environment at boot, before serving any request

A missing or malformed environment variable MUST cause the app to fail immediately and loudly at startup — never partway through handling a request, and never silently with a fallback to `undefined`.

```typescript
// src/lib/env.ts
import { z } from 'zod'

const envSchema = z.object({
  // ── Core ──────────────────────────────────────────────────────────────────
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  DATABASE_URL: z.string().url(),

  // ── Auth ──────────────────────────────────────────────────────────────────
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),

  // ── Email (Resend) ───────────────────────────────────────────────────────
  RESEND_API_KEY: z.string().min(1),
  EMAIL_FROM: z.string().email(),

  // ── Rate limiting (Upstash) ──────────────────────────────────────────────
  UPSTASH_REDIS_REST_URL: z.string().url(),
  UPSTASH_REDIS_REST_TOKEN: z.string().min(1),

  // ── Payments (Stripe) — only if billing is implied by the description ────
  STRIPE_SECRET_KEY: z.string().startsWith('sk_').optional(),
  STRIPE_WEBHOOK_SECRET: z.string().startsWith('whsec_').optional(),

  // ── Logging ──────────────────────────────────────────────────────────────
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
})

const _env = envSchema.safeParse(process.env)

if (!_env.success) {
  console.error('❌ Invalid environment variables:')
  console.error(JSON.stringify(_env.error.format(), null, 2))
  throw new Error('Invalid environment variables. Check .env.example for required values.')
}

export const env = _env.data
```

> **Why `throw` instead of `process.exit(1)` here:** Next.js's build process imports modules in contexts where `process.exit` can kill the build itself unexpectedly. Throwing an `Error` fails the build/boot cleanly while remaining catchable in test environments that intentionally probe invalid configs. For standalone scripts (seed, migration helpers) outside the Next.js runtime, `process.exit(1)` after logging is acceptable.

### 1.2 — Import `env`, never `process.env`, in application code

Once `src/lib/env.ts` exists, every other file in the codebase imports the validated `env` object instead of reading `process.env` directly. This guarantees type safety and guarantees the validation has already run.

```typescript
// ❌ Prohibited — bypasses validation, no type safety, can be undefined silently
const dbUrl = process.env.DATABASE_URL

// ✅ Required — validated, typed, guaranteed present
import { env } from '@/lib/env'
const dbUrl = env.DATABASE_URL
```

**Exception:** `src/lib/env.ts` itself necessarily reads raw `process.env` to perform the validation — this is the one file allowed to do so.

### 1.3 — Validation must cover every variable the app actually reads

Cross-reference every `process.env.X` reference in the codebase (outside `env.ts`) against the Zod schema. Any variable read directly without appearing in the schema is a validation gap and a scoring deduction. As a rule, by the end of Phase 4, no file should reference `process.env` directly except `env.ts`.

### 1.4 — Distinguish required vs optional at the type level

Use `.optional()` only for variables that are genuinely conditional (e.g., Stripe keys when billing isn't part of the app). Required variables have no `.optional()` and no silent `.default()` for values that must be explicitly set by the developer (secrets, URLs). `.default()` is appropriate only for genuinely safe defaults like `LOG_LEVEL` or `NODE_ENV`.

---

## Rule 2 — `.env.example` Completeness

### 2.1 — Every variable referenced in the Zod schema appears in `.env.example`

This is a direct one-to-one mapping — if it's in `envSchema`, it's in `.env.example`, with no exceptions in either direction.

### 2.2 — Format requirements

- Variables grouped by service/concern with comment headers.
- Every variable has an inline comment explaining what it is and, where applicable, where to obtain it.
- Placeholder values only — never a real secret, even a low-stakes one, ever committed to `.env.example`.
- Use realistic placeholder formats so the shape is obvious (e.g., `sk_test_...` for Stripe, not just `your-key-here`).

### 2.3 — Standard `.env.example` template

```bash
# ──────────────────────────────────────────────────────────────────────────
# CORE
# ──────────────────────────────────────────────────────────────────────────

# Environment mode — development | test | production
NODE_ENV=development

# PostgreSQL connection string.
# Local dev: postgresql://user:password@localhost:5432/dbname
# Production (serverless): append ?connection_limit=5&pool_timeout=10
DATABASE_URL="postgresql://appuser:changeme@localhost:5432/appdb"

# ──────────────────────────────────────────────────────────────────────────
# AUTHENTICATION (NextAuth v5)
# ──────────────────────────────────────────────────────────────────────────

# Random secret used to sign session JWTs. Generate with:
#   openssl rand -base64 32
NEXTAUTH_SECRET="replace-with-32-plus-character-random-string"

# Full URL of the deployed app. Local: http://localhost:3000
NEXTAUTH_URL="http://localhost:3000"

# ──────────────────────────────────────────────────────────────────────────
# EMAIL (Resend + react-email)
# ──────────────────────────────────────────────────────────────────────────

# API key from https://resend.com → API Keys
RESEND_API_KEY="re_xxxxxxxxxxxxxxxxxxxxx"

# Verified sender address (must match a domain verified in Resend)
EMAIL_FROM="noreply@yourdomain.com"

# ──────────────────────────────────────────────────────────────────────────
# RATE LIMITING (Upstash Redis)
# ──────────────────────────────────────────────────────────────────────────

# From https://console.upstash.com → your database → REST API
UPSTASH_REDIS_REST_URL="https://your-instance.upstash.io"
UPSTASH_REDIS_REST_TOKEN="your-upstash-token"

# ──────────────────────────────────────────────────────────────────────────
# PAYMENTS (Stripe) — only present if the app description implies billing
# ──────────────────────────────────────────────────────────────────────────

# Secret key from https://dashboard.stripe.com/apikeys (use sk_test_ in dev)
STRIPE_SECRET_KEY="sk_test_xxxxxxxxxxxxxxxxxxxxx"

# Webhook signing secret from https://dashboard.stripe.com/webhooks
STRIPE_WEBHOOK_SECRET="whsec_xxxxxxxxxxxxxxxxxxxxx"

# ──────────────────────────────────────────────────────────────────────────
# LOGGING
# ──────────────────────────────────────────────────────────────────────────

# debug | info | warn | error — use 'debug' locally, 'info' in production
LOG_LEVEL=info

# ──────────────────────────────────────────────────────────────────────────
# DOCKER COMPOSE (used only by docker-compose.yml, not by the app itself)
# ──────────────────────────────────────────────────────────────────────────

POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD="changeme-use-a-real-password-in-production"
```

### 2.4 — `.env.local` is generated by the developer, never by shipready

shipready generates `.env.example` only. The README instructs the developer to `cp .env.example .env.local` and fill in real values — shipready never writes a `.env.local` with guessed or placeholder "real" values, since that file is gitignored and personal to each environment.

---

## Rule 3 — Per-Environment Configuration

### 3.1 — Behavior that must differ between environments

| Concern | Development | Test | Production |
|---|---|---|---|
| Logging | `pino-pretty`, colorized, `debug` level available | JSON, `warn`+ only to reduce noise | JSON, `info`+, shipped to log aggregator |
| Error detail in terminal | Full stack traces printed (server-side only) | Full stack traces | Full stack traces logged, never in API response (see Error Handling Rule 4) |
| Database | Local Postgres via Docker Compose | Separate test DB, reset between runs | Managed Postgres (Vercel Postgres, Supabase, RDS) |
| Rate limiting | Can be relaxed or use an in-memory fallback if Upstash isn't configured locally | Typically disabled or mocked | Strict, as configured |
| `NEXTAUTH_URL` | `http://localhost:3000` | `http://localhost:3000` | The real production domain, HTTPS |
| Next.js telemetry | Default (on) unless disabled | Disabled (`NEXT_TELEMETRY_DISABLED=1`) | Disabled in CI/Docker builds |
| Security headers (HSTS) | Not enforced (no HTTPS locally) | N/A | `Strict-Transport-Security` enforced |

### 3.2 — Branch on `env.NODE_ENV`, never on ad hoc checks

```typescript
// ✅ Consistent — single source of truth
import { env } from '@/lib/env'

if (env.NODE_ENV === 'production') {
  // apply HSTS header
}

// ❌ Prohibited — bypasses validated env, inconsistent with the rest of the app
if (process.env.NODE_ENV === 'production') { ... }
```

### 3.3 — `next.config.ts` environment-aware settings

```typescript
// next.config.ts
const nextConfig = {
  output: 'standalone',
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'images.unsplash.com' },
    ],
  },
  // Disable telemetry collection in CI/Docker builds
  ...(process.env.CI && { telemetry: false }),
}

export default nextConfig
```

### 3.4 — Test environment isolation

If a test suite is generated, it MUST use a separate `DATABASE_URL` (e.g., a `_test` suffixed database) so running tests never touches development or seeded data. Document this in `.env.example` and the README's testing section.

---

## Rule 4 — No Hardcoded Values

### 4.1 — Absolute prohibitions

Nothing in the following categories may ever be a literal value in source code — all of it belongs in environment variables, referenced via the validated `env` object:

- API keys, secrets, tokens (covered jointly with Security dimension Rule 5)
- Database connection strings
- External service URLs (email provider, payment provider, Redis)
- The app's own canonical URL (`NEXTAUTH_URL` / base URL for generating links in emails)
- Feature flags that differ between environments
- Third-party webhook signing secrets

### 4.2 — Constants that are NOT environment variables

Not everything configurable belongs in `.env`. Values that are the same across all environments and are not secrets are application constants, not environment variables:

```typescript
// src/lib/constants.ts
export const PAGINATION_DEFAULT_LIMIT = 20
export const PAGINATION_MAX_LIMIT = 100
export const SESSION_MAX_AGE_DAYS = 30
export const RATE_LIMIT_AUTH_ATTEMPTS = 5
export const RATE_LIMIT_AUTH_WINDOW = '15 m'
```

**Decision rule:** if the value would ever need to differ between a developer's laptop and production, or if it's a credential, it's an environment variable. If it's a business rule constant that's the same everywhere, it's a named constant in code — not an env var, and not a magic number inline either.

### 4.3 — Never inline a magic number/string that should be a named constant

```typescript
// ❌ Prohibited — magic number, unclear intent, duplicated across files
if (bookings.length > 20) { ... }

// ✅ Required — named, single source of truth
import { PAGINATION_DEFAULT_LIMIT } from '@/lib/constants'
if (bookings.length > PAGINATION_DEFAULT_LIMIT) { ... }
```

### 4.4 — Self-audit before finalizing

Before Phase 6, grep-equivalent scan the generated codebase for: any string literal matching a URL pattern outside `.env.example`/`next.config.ts` remote patterns, any string literal that looks like an API key pattern (`sk_`, `re_`, `whsec_`, etc.), and any bare `process.env` reference outside `src/lib/env.ts`. Document zero findings (or the specific exception and why) in `SHIPREADY.md`.

---

## Deductions reference (Environment)

| Violation | Deduction |
|---|---|
| No Zod env validation at startup | -4 |
| App starts successfully with a missing required variable | -3 |
| Variable read via `process.env` outside `env.ts` | -1 per instance |
| Variable present in code but missing from `.env.example` | -1 per variable |
| `.env.example` contains a real (non-placeholder) credential | -3 |
| `.env.example` variable missing an explanatory comment | -0.5 per variable |
| No distinction between dev/production logging behavior | -1 |
| Hardcoded URL, key, or connection string in source | -2 per instance (also Security cross-deduction) |
| Magic number/string used instead of a named constant for a repeated business rule | -1 per instance |
| `.env.local` committed to version control | -3 (Security cross-deduction) |

---

## Checklist (use before scoring)

- [ ] `src/lib/env.ts` exists with a Zod schema covering every environment variable the app uses
- [ ] Invalid/missing env vars cause a hard failure at startup, not a runtime crash later
- [ ] Every file outside `env.ts` imports `env`, never reads `process.env` directly
- [ ] `.env.example` contains every variable from the Zod schema, and no extras
- [ ] `.env.example` variables are grouped by service with comment headers
- [ ] Every `.env.example` variable has an inline comment explaining its purpose/source
- [ ] No real credentials appear anywhere in `.env.example`
- [ ] `NODE_ENV` branching uses the validated `env.NODE_ENV`, not raw `process.env.NODE_ENV`
- [ ] Logging behavior differs appropriately between development and production
- [ ] Business-rule constants (pagination limits, rate limit thresholds) live in `src/lib/constants.ts`, not inline magic numbers
- [ ] No hardcoded URLs, keys, or connection strings anywhere in `src/`
- [ ] `.env.local` and `.env.production` are in `.gitignore`
- [ ] Test environment (if applicable) uses an isolated `DATABASE_URL`

---

*Environment dimension — shipready v1.0.0*