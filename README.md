# shipready

`/shipready` is a Claude Code skill that audits your entire codebase across 8 critical dimensions, explains every problem in plain English, fixes everything automatically, and gives you a Ship Score before you go live.

Built specifically for vibe‑coded / AI‑generated projects (Lovable, Bolt, v0, or your own ChatGPT prototypes), it transforms messy, barely‑working code into hardened, production‑ready software.

## 🚀 What It Fixes

| Category | What We Catch |
|---|---|
| Security | Hardcoded secrets, SQL injection, XSS, CSRF, unprotected routes, missing rate limiting, weak CORS, missing security headers, sensitive data in logs |
| Error Handling | Unhandled promise rejections, missing try/catch, raw stack traces to client, no global error boundary, no fallback UI |
| Database | Missing indexes, no connection pooling, no transactions, raw SQL injection, no migrations, plaintext passwords |
| API Design | No input validation, inconsistent response shapes, wrong status codes, no pagination, API keys in frontend code, no request size limits |
| Environment & Config | `.env` not in `.gitignore`, no `.env.example`, hardcoded localhost URLs, no environment‑based config, missing docs |
| Performance | N+1 queries, no caching, blocking operations in async handlers, unoptimized images |
| Frontend | No loading/error/empty states, no 404 page, leftover `console.log`, client‑side only validation |
| DevOps Readiness | No health check, no Dockerfile or deployment config, no README, missing start script, only console.log |

## 📦 Installation

### Prerequisites

- Claude Code installed (`npm install -g @anthropic-ai/claude-code`)
- Your project in a git repository (optional, but recommended)

### One‑liner (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/shipready/main/install.sh | bash
```

### Manual install (for Claude Code)

```bash
mkdir -p ~/.claude/skills/shipready
curl -o ~/.claude/skills/shipready/SKILL.md https://raw.githubusercontent.com/YOUR_GITHUB_USERNAME/shipready/main/SKILL.md
```

This installs shipready as a **personal** skill, available in every project on your machine. Claude Desktop reads from the same `~/.claude/skills/` directory, so it works there too.

### For Cursor, Windsurf, or Cline

Unlike Claude Code's personal skills, these tools read rules at the **project level**, not from your home directory — so the installer needs to be run from inside the project you want to harden, and it adapts the content to each tool's own format:

| Tool | File | Notes |
|---|---|---|
| Cursor | `.cursor/rules/shipready.mdc` | Must use the `.mdc` extension with `description`, `globs`, and `alwaysApply` frontmatter — a plain `.md` file here is silently ignored. |
| Windsurf | `.windsurf/rules/shipready.md` | Project root. |
| Cline | `.clinerules/shipready.md` | Project root. |

Run the installer from your project root and it will detect which of these tools you're using and write the adapted file to the right place.

## 🎯 Usage

### Full audit + fix

```bash
/shipready
```

This runs the complete 6‑phase workflow: detect stack → audit → report → fix → verify → score.

### Focused scans

`/shipready` reads the word you type after it to pick a mode:

| Command | Description |
|---|---|
| `/shipready scan` | Audit only, print report, touch nothing |
| `/shipready security` | Security category only – full fix |
| `/shipready db` | Database category only – full fix |
| `/shipready score` | Re‑calculate Ship Score without re‑auditing |

### Example output

```
Detected Stack:
Framework: Next.js 14 (App Router)
Database: PostgreSQL via Prisma
Auth: NextAuth.js
Deployment: Vercel
State: Zustand
Styling: Tailwind CSS

Proceeding to audit...

Found 23 issues: 4 CRITICAL, 7 HIGH, 8 MEDIUM, 4 LOW

CRITICAL - Security [SEC-001]
Hardcoded JWT secret
File: /lib/auth.js Line: 12
What's wrong: Your JWT secret is written directly in the code as a string literal.
Why it matters: Anyone who can read your source code – a contributor, someone who finds it on GitHub – can forge authentication tokens and log in as any user.
Fix: Move to process.env.JWT_SECRET and add JWT_SECRET to your .env.

How would you like to proceed?
1. Fix everything (recommended)
2. Fix CRITICAL and HIGH only
3. Fix one category at a time
4. Report only - don't touch files
```

After fixing:

```
Fixes applied across 6 files:
- /lib/auth.js - JWT secret moved to env variable
- /api/users.js - SQL queries parameterized
- /middleware/index.js - helmet + rate limiting added
- /.gitignore - .env added
- /lib/db.js - connection pooling added
- /pages/api/orders.js - pagination added

21 of 23 issues fixed automatically. 2 remain for manual review:
- [HIGH] Missing CSRF protection on /api/payments - needs your payment provider's token flow
- [LOW] console.log left in /utils/debug.js - looked intentional, confirm before removing

Ship Score: 91/100  (100 - 8 for the open HIGH - 1 for the open LOW)
You're ready to launch once you've handled the two items above.
```

A file `SHIPREADY.md` is written to your repo root with the full audit history, fixes applied, and remaining manual steps.

## ⚙️ How It Works

shipready is not a tool – it's a skill that runs inside Claude Code. Claude reads every file in your project and follows a strict 6‑phase workflow:

1. **Stack Detection** – Identifies framework, database, auth, deployment, etc.
2. **Audit Engine** – Checks code against 8 categories, tags issues with severity.
3. **The Report** – Prints every issue with a plain‑English explanation of why it matters.
4. **The Fix** – Applies fixes in priority order (CRITICAL → LOW), one category at a time, adding `[shipready]` comments to every change.
5. **Verify** – Re‑reads modified files to confirm fixes work and nothing broke.
6. **Ship Score + Report** – Calculates a score out of 100 and writes `SHIPREADY.md`.

shipready itself calls no separate APIs or third‑party services — it's a single Markdown file that runs entirely inside your existing Claude Code session, over whatever connection Claude Code already uses (the Anthropic API by default, or your own configured model backend). It doesn't add any new data path beyond what Claude Code already has.

## 📊 Ship Score

The Ship Score is a quick health indicator for your codebase. It starts at 100 and subtracts points for each unresolved issue:

| Severity | Points deducted |
|---|---|
| CRITICAL | –15 |
| HIGH | –8 |
| MEDIUM | –3 |
| LOW | –1 |

- ≥ 80 – Ready for launch (with minor manual tasks)
- 60–79 – Good, but fix HIGH and CRITICAL issues first
- < 60 – Not production‑ready – fix the criticals immediately

## 🔧 Specialized Variants

We provide stack‑specific versions that fine‑tune the audit for your framework:

| Variant | File | Use with |
|---|---|---|
| General | `SKILL.md` | Any stack (auto‑detects) |
| Next.js + Prisma + PostgreSQL | `SKILL.nextjs-prisma-postgres.md` | Next.js apps with Prisma and PostgreSQL |
| (more coming) | | |

To use a specialized variant, copy the respective file to your `~/.claude/skills/shipready/` directory in place of (or alongside) `SKILL.md`.

## ❓ Frequently Asked Questions

**Will shipready break my code?**
No – it reads surrounding code deeply and never deletes existing functionality. It only adds or modifies code to fix issues, and always flags anything it can't confidently fix for manual review.

**Can I run it on an existing production app?**
Absolutely. It will identify any gaps in your security, error handling, and performance – even if you've already deployed.

**What if my project uses a stack not listed?**
The general `SKILL.md` auto‑detects most common stacks (Node.js, Python, Go, etc.). If it misses something, it will ask one clarifying question.

**Does it require an internet connection?**
Yes. shipready runs inside Claude Code, and Claude Code needs an internet connection to reach the Anthropic API (or whatever model backend you've configured) to actually do the analysis. shipready doesn't introduce a separate third‑party service — your code is read locally and processed over the same connection Claude Code already uses for everything else. This isn't an offline tool.

**How long does it take?**
For a medium‑sized project (50–100 files), the audit takes about 30–60 seconds. Fixes are applied incrementally.

## 🤝 Contributing

We welcome contributions! If you'd like to improve the skill, add a new stack variant, or fix a bug:

1. Fork the repo.
2. Create a branch for your feature.
3. Submit a pull request.

Please test your changes on at least two real‑world projects before submitting.

## 📄 License

MIT © [Your Name]

## 📣 Stay in Touch

- GitHub: github.com/YOUR_GITHUB_USERNAME
- X / Twitter: @YOUR_HANDLE

## 🙌 Why We Built This

Most AI‑generated code is a functional prototype, not a production‑grade application. It works in dev, but the moment it sees real traffic, it breaks, gets hacked, or runs out of memory.

We built shipready because we were tired of spending hours manually fixing the same issues: hardcoded secrets, missing indexes, no error handling, SQL injection, and the list goes on.

Now you can go from "it works on my machine" to "it works in production" with a single command.