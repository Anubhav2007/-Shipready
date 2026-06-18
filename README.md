# 🚢 ShipReady

> **Turn AI-generated code into production-ready software in one command.**

ShipReady is a Claude Code skill that performs a full production-readiness audit across your entire codebase, automatically fixes common issues, and generates a launch readiness score.

Built specifically for projects created with AI coding tools such as **Claude Code**, **Lovable**, **Bolt**, **v0**, **Cursor**, **Windsurf**, and **ChatGPT**, ShipReady helps transform prototypes into software you can confidently deploy.

---

## ✨ What ShipReady Does

Run a single command:

```bash
/shipready
```

ShipReady will:

* Detect your technology stack
* Audit your codebase across 8 critical dimensions
* Explain every issue in plain English
* Automatically apply safe fixes
* Verify all changes
* Generate a production readiness report
* Calculate a Ship Score out of 100

The result is a cleaner, safer, faster, and more maintainable application.

---

# 🔍 Audit Categories

ShipReady evaluates your project across the areas that most commonly cause production failures.

| Category                 | Checks                                                                     |
| ------------------------ | -------------------------------------------------------------------------- |
| 🔒 Security              | Secrets, SQL injection, XSS, CSRF, CORS, security headers, rate limiting   |
| ⚠️ Error Handling        | Missing try/catch, unhandled promises, error boundaries, stack trace leaks |
| 🗄️ Database             | Indexes, pooling, migrations, transaction handling, password storage       |
| 🌐 API Design            | Validation, response consistency, status codes, pagination                 |
| ⚙️ Environment & Config  | `.env` management, hardcoded URLs, configuration hygiene                   |
| 🚀 Performance           | N+1 queries, caching opportunities, blocking operations                    |
| 🎨 Frontend Quality      | Loading states, error states, empty states, routing issues                 |
| 🏗️ Deployment Readiness | Docker, health checks, README, deployment configuration                    |

---

# 📦 Installation

## Prerequisites

* Claude Code installed

```bash
npm install -g @anthropic-ai/claude-code
```

* Git repository (recommended)

---

## One-Line Installation

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/shipready/main/install.sh | bash
```

---

## Manual Installation

```bash
mkdir -p ~/.claude/skills/shipready

curl -o ~/.claude/skills/shipready/SKILL.md \
https://raw.githubusercontent.com/YOUR_USERNAME/shipready/main/SKILL.md
```

Once installed, ShipReady becomes available in every Claude Code session.

---

# 🚀 Usage

## Full Audit + Auto Fix

```text
/shipready
```

Runs the complete workflow:

1. Detect stack
2. Audit project
3. Generate report
4. Apply fixes
5. Verify fixes
6. Calculate Ship Score

---

## Audit Only

```text
/shipready scan
```

Reports issues without modifying files.

---

## Security Only

```text
/shipready security
```

Focus exclusively on security vulnerabilities.

---

## Database Only

```text
/shipready db
```

Analyze database structure and query performance.

---

## Recalculate Score

```text
/shipready score
```

Generates an updated Ship Score without running a full audit.

---

# 📊 Example Output

```text
Detected Stack:
Framework: Next.js 14
Database: PostgreSQL
ORM: Prisma
Authentication: NextAuth.js
Deployment: Vercel

Proceeding to audit...

Found 23 issues:
4 Critical
7 High
8 Medium
4 Low

[CRITICAL] Hardcoded JWT Secret

File:
lib/auth.js

Why it matters:
Attackers can forge authentication tokens.

Fix:
Move secret to process.env.JWT_SECRET
```

After fixes:

```text
Fixes Applied:
✓ JWT secret moved to environment variable
✓ SQL queries parameterized
✓ Security headers added
✓ Rate limiting enabled
✓ Connection pooling configured

Remaining Issues:
2 require manual review

Ship Score: 91/100
```

---

# 📈 Ship Score

ShipReady assigns a score from **0–100** representing deployment readiness.

### Scoring System

| Severity | Deduction |
| -------- | --------- |
| Critical | -15       |
| High     | -8        |
| Medium   | -3        |
| Low      | -1        |

### Interpretation

| Score    | Status                 |
| -------- | ---------------------- |
| 80–100   | ✅ Ready to Launch      |
| 60–79    | ⚠️ Needs Improvement   |
| Below 60 | ❌ Not Production Ready |

---

# ⚙️ How ShipReady Works

ShipReady follows a structured six-phase workflow.

## 1. Stack Detection

Identifies:

* Framework
* Database
* ORM
* Authentication
* Deployment Platform
* State Management

---

## 2. Audit Engine

Scans every file and categorizes findings by:

* Severity
* Risk
* Impact
* Fixability

---

## 3. Plain-English Reporting

Every issue includes:

* What is wrong
* Why it matters
* Recommended fix

No vague linting messages.

---

## 4. Automatic Remediation

Safe fixes are applied automatically.

Examples:

* Move secrets to environment variables
* Add input validation
* Add missing indexes
* Configure rate limiting
* Standardize API responses

---

## 5. Verification

Modified files are re-read and validated to ensure fixes are consistent and do not introduce regressions.

---

## 6. Reporting

ShipReady generates:

```text
SHIPREADY.md
```

Containing:

* Audit history
* Fixes applied
* Remaining issues
* Ship Score
* Recommended next actions

---

# 🏗️ Repository Structure

```text
shipready/
│
├── SKILL.md
├── install.sh
│
├── shipready.md
├── shipready-scan.md
├── shipready-security.md
├── shipready-db.md
└── shipready-score.md
```

### Core Components

| File                  | Purpose                     |
| --------------------- | --------------------------- |
| shipready.md          | Main workflow orchestration |
| shipready-scan.md     | Static analysis engine      |
| shipready-security.md | Security auditing rules     |
| shipready-db.md       | Database evaluation logic   |
| shipready-score.md    | Scoring and reporting       |

---

# 🔧 Framework-Specific Variants

ShipReady supports specialized audit profiles.

### General

```text
SKILL.md
```

Works with most stacks.

---

### Next.js + Prisma + PostgreSQL

```text
SKILL.nextjs-prisma-postgres.md
```

Provides additional checks for:

* Prisma schema design
* PostgreSQL indexing
* Next.js App Router patterns
* API route security

More stack-specific variants are planned.

---

# 🧠 Why ShipReady Exists

Most AI-generated applications are impressive demos but poor production systems.

Common problems include:

* Hardcoded secrets
* Missing validation
* SQL injection vulnerabilities
* No error handling
* Poor API design
* Missing deployment configuration
* Performance bottlenecks

ShipReady automates the production-hardening process so developers can spend less time fixing boilerplate issues and more time building products.

---

# 🤝 Contributing

Contributions are welcome.

To contribute:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on real-world projects
5. Submit a pull request

We especially welcome:

* New framework support
* Additional audit categories
* Security rule improvements
* Better fix strategies

---

# 🗺️ Roadmap

* [ ] React Native profile
* [ ] Django profile
* [ ] FastAPI profile
* [ ] Laravel profile
* [ ] Spring Boot profile
* [ ] Docker hardening checks
* [ ] CI/CD pipeline auditing
* [ ] Kubernetes readiness scoring
* [ ] Multi-repository auditing

---

# 📄 License

MIT License

Copyright (c) 2026

---

# ⭐ Support the Project

If ShipReady helped you launch faster, consider giving the repository a star.

It helps others discover the project and supports continued development.

---

**From prototype → production, with a single command.**
