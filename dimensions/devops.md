# DevOps Dimension — shipready v1.0.0

> **Max points: 10** | This dimension covers containerization, orchestration, health monitoring, CI/CD, and everything needed for a zero-friction deployment pipeline. A perfect DevOps score means any developer on any machine can clone → configure → run → deploy in under 15 minutes.

---

## Scoring Breakdown

| Sub-dimension | Points | Failure condition |
|---|---|---|
| Dockerfile (multi-stage, secure) | 2 | Missing, single-stage, or runs as root |
| docker-compose (services + healthchecks) | 2 | Missing or no health checks on DB |
| Health check route `/api/health` | 2 | Missing, always returns 200, or no DB probe |
| README with exact deploy commands | 2 | Vague instructions, missing env table, no deploy section |
| CI workflow (GitHub Actions) | 2 | Missing entirely |

---

## Rule 1 — Dockerfile (multi-stage, non-root, reproducible)

Every generated app MUST have a multi-stage Dockerfile. Single-stage Dockerfiles are prohibited.

### Required stages

| Stage | Base | Purpose |
|---|---|---|
| `deps` | `node:20-alpine` | Install production dependencies only (`npm ci --only=production`) |
| `builder` | `node:20-alpine` | Full build including devDependencies, runs `prisma generate` and `npm run build` |
| `runner` | `node:20-alpine` | Minimal production image, copies only build output |

### Security requirements

- **Non-root user mandatory.** Create a system group and user in the runner stage:
  ```dockerfile
  RUN addgroup --system --gid 1001 nodejs
  RUN adduser --system --uid 1001 nextjs
  USER nextjs
  ```
- **No secrets in the image.** Never use `ENV` for runtime secrets. All secrets must be injected at container runtime via environment variables or a secrets manager.
- **No `.env` files copied into the image.** Add `.env*` to `.dockerignore`.
- **Pin the base image tag.** `node:20-alpine` is acceptable. `node:latest` is prohibited.
- **`EXPOSE` must match the actual port.** If `PORT` is configurable via env, set `ENV PORT 3000` as default and reference it in `CMD`.

### `.dockerignore` requirements

Must exclude at minimum:
```
node_modules
.next
.env*
*.log
.git
.gitignore
README.md
SHIPREADY.md
prisma/migrations
```

### Standard Dockerfile template

```dockerfile
FROM node:20-alpine AS base

# ── Stage 1: Install production deps ──────────────────────────────────────────
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

# ── Stage 2: Build ────────────────────────────────────────────────────────────
FROM base AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
ENV NEXT_TELEMETRY_DISABLED 1
RUN npm run build

# ── Stage 3: Production runner ────────────────────────────────────────────────
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000
ENV PORT 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

CMD ["node", "server.js"]
```

> **Note:** The `HEALTHCHECK` instruction in the Dockerfile applies when using `docker run` directly. The `docker-compose.yml` healthcheck overrides this at the orchestration level.

---

## Rule 2 — docker-compose.yml (services, healthchecks, named volumes)

### Required services

| Service | Image | Required healthcheck |
|---|---|---|
| `db` | `postgres:16-alpine` | `pg_isready` |
| `redis` | `redis:7-alpine` | `redis-cli ping` |
| `app` | Local build | `wget /api/health` |

### Service dependency rules

- `app` must declare `depends_on` with `condition: service_healthy` for `db`.
- Never start the app before the DB reports healthy. A race condition here means every first deploy fails silently.
- `redis` does not block app startup (rate limiter degrades gracefully), so `depends_on` for redis uses `condition: service_started`.

### Volume rules

- All persistent data MUST use named volumes, never bind mounts for production services.
- Named volumes: `postgres_data`, `redis_data`.
- Declare all named volumes in the top-level `volumes:` key.

### Environment rules

- `app` service must use `env_file: .env.local` — never hardcode any value in docker-compose.yml.
- `db` and `redis` services may use `environment:` with `${VAR:-default}` syntax for non-secret values (DB name, user). The password MUST come from `${POSTGRES_PASSWORD}` with no default.

### Standard docker-compose.yml template

```yaml
version: '3.9'

services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-appdb}
      POSTGRES_USER: ${POSTGRES_USER:-appuser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-appuser} -d ${POSTGRES_DB:-appdb}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: runner
    restart: unless-stopped
    ports:
      - "3000:3000"
    env_file: .env.local
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

volumes:
  postgres_data:
  redis_data:
```

---

## Rule 3 — Health check route `/api/health`

### Requirements

- Must be at `src/app/api/health/route.ts`.
- Must be **publicly accessible** (no auth middleware on this route). Add an explicit bypass in `middleware.ts`.
- Must probe the database with a real query — not just return `200 OK`.
- Must return a structured JSON body in both success and failure cases.
- Must return HTTP `503` when any critical dependency is down.
- Must NOT expose internal error messages, stack traces, or DB connection strings in the response.

### Response shape

**Healthy (200):**
```json
{
  "status": "ok",
  "timestamp": "2025-01-15T10:30:00.000Z",
  "version": "1.0.0",
  "services": {
    "database": "connected",
    "cache": "connected"
  },
  "uptime": 3600
}
```

**Unhealthy (503):**
```json
{
  "status": "error",
  "timestamp": "2025-01-15T10:30:00.000Z",
  "version": "1.0.0",
  "services": {
    "database": "disconnected",
    "cache": "unknown"
  }
}
```

### Standard implementation

```typescript
// src/app/api/health/route.ts
import { NextResponse } from 'next/server'
import { prisma } from '@/lib/prisma'
import { redis } from '@/lib/redis'
import { logger } from '@/lib/logger'

const startTime = Date.now()

export const dynamic = 'force-dynamic'

export async function GET() {
  const timestamp = new Date().toISOString()
  const version = process.env.npm_package_version ?? 'unknown'
  const uptime = Math.floor((Date.now() - startTime) / 1000)

  const services: Record<string, 'connected' | 'disconnected' | 'unknown'> = {
    database: 'unknown',
    cache: 'unknown',
  }

  try {
    await prisma.$queryRaw`SELECT 1`
    services.database = 'connected'
  } catch (err) {
    logger.error({ err }, 'Health check: database unreachable')
    services.database = 'disconnected'
  }

  try {
    await redis.ping()
    services.cache = 'connected'
  } catch (err) {
    logger.warn({ err }, 'Health check: cache unreachable')
    services.cache = 'disconnected'
  }

  const isHealthy = services.database === 'connected'

  return NextResponse.json(
    { status: isHealthy ? 'ok' : 'error', timestamp, version, services, uptime },
    { status: isHealthy ? 200 : 503 }
  )
}
```

> **Note:** Redis failure is a warning, not a fatal error. The app degrades gracefully (rate limiting skips), so only DB failure triggers 503.

---

## Rule 4 — README.md (complete, copy-pasteable)

The README is the first thing every developer sees. It must allow a cold-start to running app in under 15 minutes without reading any other file.

### Required sections (in order)

**1. Header**
```markdown
# AppName
> One-sentence description of what this app does and who it's for.

![Next.js](https://img.shields.io/badge/Next.js-14-black)
![TypeScript](https://img.shields.io/badge/TypeScript-5-blue)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16-blue)
![Prisma](https://img.shields.io/badge/Prisma-5-darkgreen)
```

**2. Prerequisites**
List exact version requirements:
- Node.js ≥ 20.x
- PostgreSQL ≥ 14 (or Docker)
- Redis ≥ 7 (or Docker)
- npm ≥ 10.x

**3. Quick start (Docker — recommended)**
```bash
# Clone and configure
git clone <repo-url> && cd <app-name>
cp .env.example .env.local
# Edit .env.local — fill in POSTGRES_PASSWORD, NEXTAUTH_SECRET, etc.

# Start all services
docker compose up -d

# Run migrations and seed
docker compose exec app npx prisma migrate deploy
docker compose exec app npx prisma db seed

# App is live at http://localhost:3000
```

**4. Quick start (local dev)**
```bash
cp .env.example .env.local
# Edit .env.local

npm install
npx prisma migrate dev --name init
npx prisma db seed
npm run dev
# App is live at http://localhost:3000
```

**5. Environment variables table**

| Variable | Required | Description | Where to get it |
|---|---|---|---|
| `DATABASE_URL` | ✅ | PostgreSQL connection string | Local: `postgresql://user:pass@localhost:5432/dbname` |
| `NEXTAUTH_SECRET` | ✅ | Random 32+ char string for JWT signing | Run: `openssl rand -base64 32` |
| `NEXTAUTH_URL` | ✅ | Full URL of deployed app | Local: `http://localhost:3000` |
| `RESEND_API_KEY` | ✅ | Transactional email provider key | [resend.com](https://resend.com) → API Keys |
| `UPSTASH_REDIS_REST_URL` | ✅ | Upstash Redis URL | [console.upstash.com](https://console.upstash.com) |
| `UPSTASH_REDIS_REST_TOKEN` | ✅ | Upstash Redis token | [console.upstash.com](https://console.upstash.com) |

**6. API reference** — Every endpoint. See API Design dimension for format requirements.

**7. Database schema** — ASCII table relationships or bullet list of models and key fields.

**8. Deployment**

Must include deployment instructions for all three targets:
- **Vercel** (primary): `vercel --prod`, required env vars, Postgres addon
- **Railway**: GUI walkthrough, service wiring
- **Docker** (self-hosted): `docker compose up -d --build`, nginx reverse proxy note

**9. Seed credentials**

```
Admin account:
  Email: admin@example.com
  Password: Admin1234!

Test user:
  Email: user@example.com
  Password: User1234!
```

**10. npm scripts reference**

| Script | Command | Description |
|---|---|---|
| Dev server | `npm run dev` | Starts Next.js with hot reload |
| Production build | `npm run build` | Compiles for production |
| Start production | `npm start` | Serves compiled build |
| Lint | `npm run lint` | ESLint check |
| DB migrate | `npm run db:migrate` | Run pending migrations |
| DB seed | `npm run db:seed` | Seed database with test data |
| DB studio | `npm run db:studio` | Open Prisma Studio on :5555 |
| Type check | `npm run typecheck` | `tsc --noEmit` |

---

## Rule 5 — CI/CD workflow (GitHub Actions)

### Required: `.github/workflows/ci.yml`

Must run on every push to `main` and every pull request targeting `main`.

### Required jobs

| Job | Steps |
|---|---|
| `lint` | Checkout → Setup Node → `npm ci` → `npm run lint` → `npm run typecheck` |
| `test` | Checkout → Setup Node → `npm ci` → `npx prisma generate` → `npm test` (if tests exist) |
| `build` | Checkout → Setup Node → `npm ci` → `npx prisma generate` → `npm run build` |
| `docker` | Checkout → Docker Buildx → Build image (no push on PR, push on merge to main if registry configured) |

### Standard CI template

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint:
    name: Lint & Type Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck

  build:
    name: Build
    runs-on: ubuntu-latest
    needs: lint
    env:
      # Dummy values for build-time env validation
      DATABASE_URL: postgresql://user:pass@localhost:5432/db
      NEXTAUTH_SECRET: ci-secret-at-least-32-characters-long
      NEXTAUTH_URL: http://localhost:3000
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npx prisma generate
      - run: npm run build

  docker:
    name: Docker Build
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - name: Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          tags: app:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Deductions reference (DevOps)

| Violation | Deduction |
|---|---|
| Single-stage Dockerfile | -2 |
| App runs as root in container | -2 |
| Health check missing DB probe | -1 |
| Health check always returns 200 | -2 |
| Stack trace or internal error in health check response | -1 |
| docker-compose missing DB healthcheck | -1 |
| App service starts without `depends_on: condition: service_healthy` | -1 |
| README missing copy-pasteable setup commands | -1 |
| README missing environment variables table | -1 |
| CI workflow missing entirely | -2 |
| Secrets hardcoded in docker-compose.yml or Dockerfile | -5 (Security cross-deduction) |

---

## Checklist (use before scoring)

- [ ] Dockerfile has 3 stages: `deps`, `builder`, `runner`
- [ ] Runner stage creates and uses a non-root user
- [ ] `.dockerignore` excludes `.env*`, `node_modules`, `.next`
- [ ] `docker-compose.yml` has `db`, `redis`, and `app` services
- [ ] Each service has a `healthcheck` block
- [ ] `app` depends on `db` with `condition: service_healthy`
- [ ] All volumes are named (not bind mounts)
- [ ] `/api/health` route exists and probes the database
- [ ] `/api/health` returns `503` when DB is down
- [ ] Health route is excluded from auth middleware
- [ ] README has Quick Start (Docker AND local)
- [ ] README has environment variables table with "where to get it" column
- [ ] README has all three deployment targets (Vercel, Railway, Docker)
- [ ] README lists default seed credentials
- [ ] `.github/workflows/ci.yml` exists with lint + build + docker jobs

---

*DevOps dimension — shipready v1.0.0*