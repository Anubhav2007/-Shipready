# shipready Score Calculation Guide

## 📊 Ship Score Overview

The Ship Score is a quantitative measure of a codebase's production readiness across 8 dimensions. A score of 100 represents perfect compliance with all shipready standards.

| Threshold | Score |
|-----------|-------|
| Minimum Viable | 70/100 |
| Production Ready | 85/100 |
| Perfect Score | 100/100 |

## 📐 Scoring Rubric

### Dimension Weightings

| Dimension | Max Points | Weight | Importance |
|-----------|-----------|--------|------------|
| Security | 15 | 15% | CRITICAL |
| Database | 15 | 15% | HIGH |
| Error Handling | 10 | 10% | HIGH |
| API Design | 10 | 10% | MEDIUM |
| Environment | 10 | 10% | HIGH |
| Performance | 15 | 15% | MEDIUM |
| Frontend | 15 | 15% | MEDIUM |
| DevOps | 10 | 10% | HIGH |

---

### Security (15 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| Authentication | 3 | NextAuth/valid auth system |
| Password Hashing | 2 | bcrypt/argon2 |
| Input Validation | 2 | Zod/Yup schemas |
| Rate Limiting | 2 | Upstash/Redis |
| CORS Configuration | 1 | Origin whitelist |
| Security Headers | 1 | All headers present |
| Secrets Management | 2 | No hardcoded secrets |
| SQL Injection Protection | 2 | Prepared statements |

### Database (15 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| Schema Design | 3 | Complete models with relations |
| Indexes | 3 | All queried fields indexed |
| Migrations | 2 | Version-controlled migrations |
| Seed Data | 2 | Realistic test data |
| Query Optimization | 2 | No N+1 queries |
| Connection Pooling | 1 | Production config |
| Backup Strategy | 1 | Documented |
| Soft Delete | 1 | Implemented if needed |

### Error Handling (10 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| Global Error Boundary | 2 | error.tsx present |
| Consistent Responses | 2 | Uniform error shapes |
| Structured Logging | 2 | Pino/logger |
| No Stack Traces | 2 | Not exposed to clients |
| User-Friendly Messages | 1 | Not technical errors |
| API Error Handling | 1 | All routes covered |

### API Design (10 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| RESTful Conventions | 2 | Proper HTTP methods |
| Versioning | 2 | /api/v1/ pattern |
| Pagination | 2 | All list endpoints |
| Response Consistency | 2 | Uniform shape |
| HTTP Semantics | 1 | Proper status codes |
| Documentation | 1 | OpenAPI/README |

### Environment (10 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| Startup Validation | 3 | Zod/env validation |
| .env.example | 2 | Complete with comments |
| No Hardcoded Values | 2 | All in env |
| Per-Environment Configs | 2 | dev/staging/prod |
| Secrets Rotation | 1 | Documented process |

### Performance (15 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| Lazy Loading | 2 | React.lazy/next/dynamic |
| Image Optimization | 2 | Next/Image |
| Caching Strategy | 2 | Redis/CDN |
| Query Efficiency | 2 | Optimized queries |
| Pagination | 2 | All list endpoints |
| Bundle Size | 2 | Code splitting |
| CDN Configuration | 1 | Static assets |
| Monitoring | 2 | Performance tracking |

### Frontend (15 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| Loading States | 3 | Loading skeletons/spinners |
| Error States | 3 | Error boundaries/messages |
| Empty States | 2 | No data UI |
| Accessibility | 2 | ARIA labels, keyboard |
| Form Validation | 2 | React-hook-form/Zod |
| Responsive Design | 1 | Mobile-first |
| Toast Notifications | 2 | User feedback |

### DevOps (10 points)

| Criteria | Points | Requirement |
|----------|--------|-------------|
| Dockerfile | 2 | Production optimized |
| docker-compose.yml | 2 | All services |
| Health Check | 2 | /api/health endpoint |
| README | 2 | Complete instructions |
| CI/CD Pipeline | 1 | GitHub Actions |
| Monitoring | 1 | Logging/metrics |

## 📊 Score Calculation

### Formula
```
Ship Score = Security + Database + Error + API + Environment + Performance + Frontend + DevOps
```
(Max 100 points total across all dimensions)

### Example Calculation
```typescript
const scores = {
  security: 12,      // Missing rate limiting (-3)
  database: 15,      // Perfect
  errorHandling: 8,  // Missing global boundary (-2)
  apiDesign: 9,      // Missing pagination (-1)
  environment: 10,   // Perfect
  performance: 11,   // Missing caching (-4)
  frontend: 13,      // Missing accessibility (-2)
  devops: 7          // Missing health check (-3)
}
// Ship Score: 85/100
```

## 🚫 Automatic Deductions

| Violation | Points Deducted |
|-----------|----------------|
| Hardcoded secret | -5 per occurrence |
| Exposed stack trace | -5 per occurrence |
| Missing loading/error/empty state | -3 per state |
| Missing DB index | -3 per field |
| Unprotected admin route | -5 per route |
| console.log instead of logger | -2 per usage |
| Missing SHIPREADY.md | -10 |
| Placeholder function | -10 per function |
| CORS with * wildcard | -5 |
| No rate limiting | -5 |
| No input validation | -3 per endpoint |

## 🏆 Score Tiers

| Score | Grade | Meaning |
|-------|-------|---------|
| 95–100 | A+ | Perfect, production-ready |
| 85–94 | A | Ready for production |
| 70–84 | B | Needs improvements |
| 50–69 | C | Major issues |
| 0–49 | F | Not production-ready |

## 📈 Score Improvement

### Quick Wins (5–10 points)
1. Add rate limiting (+3–5)
2. Fix hardcoded secrets (+5)
3. Add health check (+2)
4. Remove console.log (+2–3)

### Medium Effort (10–20 points)
1. Add missing states (+5–9)
2. Add missing indexes (+3)
3. Implement pagination (+2)
4. Add validation (+3)

### Major Effort (20–30 points)
1. Implement auth (+5)
2. Add Docker (+4)
3. Optimize queries (+2)
4. Add monitoring (+2)

## 🎯 Target Scores by Stage

| Stage | Target Score | Focus Areas |
|-------|--------------|-------------|
| MVP/Prototype | 70+ | Critical security, basic UX |
| Beta | 80+ | All dimensions covered |
| Production | 85+ | All dimensions completed |
| Enterprise | 90+ | Perfect in all dimensions |

### Minimum Requirements per Dimension
| Dimension | Minimum Score |
|-----------|---------------|
| Security | 12/15 |
| Database | 12/15 |
| Error Handling | 8/10 |
| DevOps | 7/10 |

## 🔄 Score Tracking Example

```markdown
## Score Improvement Report

### Initial Score: 65/100
- Security: 8/15 ❌
- Database: 12/15 ✅
- Error: 5/10 ❌
- API: 7/10 ⚠️
- Environment: 9/10 ✅
- Performance: 10/15 ⚠️
- Frontend: 11/15 ✅
- DevOps: 4/10 ❌

### After Fixes: 87/100
- Security: 14/15 ✅
- Database: 14/15 ✅
- Error: 9/10 ✅
- API: 9/10 ✅
- Environment: 10/10 ✅
- Performance: 13/15 ✅
- Frontend: 14/15 ✅
- DevOps: 9/10 ✅

### Improvement: +22 points
```

---

**The Ship Score provides a clear, objective measure of production readiness across all 8 dimensions.**