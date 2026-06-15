## Dimension rules (complete)

### Dimension 5 — Environment

| Rule | Requirement |
|---|---|
| Startup validation | `src/lib/env.ts` validates all required variables at startup using Zod. Process exits with a clear error if any are missing or malformed. |
| `.env.example` | Every variable with a comment. Placeholder values that clearly indicate what's needed. Grouped by service. |
| Separate environments | `.env.local` (dev), `.env.test` (tests), `.env.production` (never in the repo). |
| No hardcoded values | Not a single URL, key, secret, or config value hardcoded anywhere. All via `env.*`. |
| Documentation | README includes a full environment variables table. |

**`.env.example` format:**

```bash
# ──────────────────────────────────────────────────────────────────────
# DATABASE
# ──────────────────────────────────────────────────────────────────────
# Full PostgreSQL connection string
# Local: postgresql://user:password@localhost:5432/dbname
# Production: get from Railway/Neon/Supabase dashboard
DATABASE_URL="postgresql://appuser:password@localhost:5432/appdb"

# ──────────────────────────────────────────────────────────────────────
# AUTHENTICATION (NextAuth.js)
# ──────────────────────────────────────────────────────────────────────
# Run: openssl rand -base64 32
NEXTAUTH_SECRET="your-32-char-secret-here"
# Your app's public URL (no trailing slash)
NEXTAUTH_URL="http://localhost:3000"

# ──────────────────────────────────────────────────────────────────────
# RATE LIMITING (Upstash Redis)
# ──────────────────────────────────────────────────────────────────────
# Create a free Redis database at https://upstash.com
UPSTASH_REDIS_REST_URL="https://xxx.upstash.io"
UPSTASH_REDIS_REST_TOKEN="your-token-here"

# ──────────────────────────────────────────────────────────────────────
# EMAIL (Resend)
# ──────────────────────────────────────────────────────────────────────
# Create a free account at https://resend.com
RESEND_API_KEY="re_xxxxxxxxxxxx"
EMAIL_FROM="noreply@yourdomain.com"

# ──────────────────────────────────────────────────────────────────────
# APPLICATION
# ──────────────────────────────────────────────────────────────────────
NEXT_PUBLIC_APP_URL="http://localhost:3000"
NEXT_PUBLIC_APP_NAME="Your App Name"
NODE_ENV="development"
LOG_LEVEL="info"
# Comma-separated list of allowed CORS origins
ALLOWED_ORIGINS="http://localhost:3000"
```

---
