# shipready Scan Mode

## 📋 Overview

**Status:** Available in v1.1+

The scan mode audits an existing codebase against all 8 shipready dimensions, identifying violations and providing a detailed report with prioritized fixes.

## 🎯 Purpose

1. **Audit existing projects** against shipready standards
2. **Identify security vulnerabilities** and performance issues
3. **Generate improvement roadmap** with prioritized fixes
4. **Measure codebase quality** with Ship Score
5. **Validate production readiness** before deployment

## 🔍 What It Scans

### 1. Security Dimension
- [ ] Auth implementation (NextAuth/other)
- [ ] Password hashing (bcrypt/argon2)
- [ ] Input validation (Zod/Yup)
- [ ] Rate limiting implementation
- [ ] CORS configuration
- [ ] Security headers
- [ ] Secrets management
- [ ] SQL injection prevention

### 2. Database Dimension
- [ ] Prisma schema design
- [ ] Indexes on queried fields
- [ ] Migration files
- [ ] Seed data
- [ ] Connection pooling
- [ ] Query optimization
- [ ] Soft delete pattern
- [ ] Backup strategy

### 3. Error Handling Dimension
- [ ] Global error boundary
- [ ] Consistent error responses
- [ ] Structured logging
- [ ] Stack trace exposure
- [ ] User-friendly error pages
- [ ] API error handling

### 4. API Design Dimension
- [ ] RESTful conventions
- [ ] Versioning strategy
- [ ] Pagination implementation
- [ ] Response consistency
- [ ] HTTP semantics
- [ ] OpenAPI/Swagger docs

### 5. Environment Dimension
- [ ] Environment validation
- [ ] .env.example file
- [ ] No hardcoded values
- [ ] Per-environment configs
- [ ] Secrets rotation strategy

### 6. Performance Dimension
- [ ] Lazy loading
- [ ] Image optimization
- [ ] Caching strategy
- [ ] Query efficiency
- [ ] Bundle size optimization
- [ ] CDN configuration

### 7. Frontend Dimension
- [ ] Loading states
- [ ] Error states
- [ ] Empty states
- [ ] Accessibility (a11y)
- [ ] Form validation
- [ ] Responsive design
- [ ] Toast notifications

### 8. DevOps Dimension
- [ ] Dockerfile
- [ ] docker-compose.yml
- [ ] Health check endpoint
- [ ] README completeness
- [ ] CI/CD pipeline
- [ ] Monitoring setup
- [ ] Logging infrastructure

## 📊 Scan Output Format

### Audit Report Template
```markdown
# shipready Audit Report
Generated: [ISO timestamp]
Project: [project-name]
Repository: [git remote]
Branch: [current branch]

---

## Ship Score: XX/100

| Dimension          | Score | Issues Found | Status |
|--------------------|-------|--------------|--------|
| Security           | 8/15  | 4            | ⚠️     |
| Database           | 12/15 | 2            | ✅     |
| Error Handling     | 5/10  | 3            | ❌     |
| API Design         | 7/10  | 2            | ⚠️     |
| Environment        | 9/10  | 1            | ✅     |
| Performance        | 10/15 | 3            | ⚠️     |
| Frontend           | 11/15 | 2            | ✅     |
| DevOps             | 4/10  | 5            | ❌     |
```

### Issue Categories

**🔴 Critical Issues (Fix Immediately)**
- Security vulnerabilities
- Exposed secrets
- No authentication
- Unprotected admin routes

**🟡 High Priority Issues (Fix Soon)**
- Missing health checks
- No logging
- Poor error handling
- Missing migrations

**🟢 Medium Priority Issues (Fix When Possible)**
- Missing loading states
- No pagination
- Missing indexes
- No documentation

**⚪ Low Priority Issues (Nice to Have)**
- Code style issues
- Minor optimizations
- Additional comments

## 🛠️ Scan Implementation

### Scan Command
```bash
/shipready:scan [path]
```

### Scan Process
1. **Analyze project structure** — check for required files, verify package.json dependencies, examine folder organization
2. **Audit each dimension** — run automated checks, parse configuration files, analyze code patterns
3. **Generate report** — compile findings, calculate scores, provide recommendations
4. **Create action plan** — prioritize fixes, estimate effort, suggest timeline

### Code Analysis Examples

**Security Check**
```typescript
function scanForSecrets(content: string) {
  const patterns = [
    /secret.*=.*['"][^'"]+['"]/gi,
    /password.*=.*['"][^'"]+['"]/gi,
    /api[_-]key.*=.*['"][^'"]+['"]/gi
  ]
  return patterns.some(pattern => pattern.test(content))
}
```

**Database Check**
```typescript
function scanForIndexes(schema: string) {
  const models = parsePrismaSchema(schema)
  return models.map(model => ({
    name: model.name,
    hasIndexes: model.indexes.length > 0,
    missingIndexes: findMissingIndexes(model)
  }))
}
```

## 📈 Improvement Tracking

### After Fixes Summary
```markdown
## 📈 Improvement Summary

### By Dimension
- Security: +7 points (from 8 to 15)
- Error Handling: +5 points (from 5 to 10)
- DevOps: +6 points (from 4 to 10)

### New Ship Score After Fixes: **87/100**
```

### Progress Tracking
```markdown
## ✅ Recommendations

### Immediate Actions (Week 1)
1. [ ] Implement rate limiting (1 hour)
2. [ ] Fix hardcoded secrets (30 minutes)
3. [ ] Create health check (30 minutes)

### Short-term (Week 2)
4. [ ] Build Dockerfile (1 hour)
5. [ ] Add missing indexes (30 minutes)
6. [ ] Implement loading states (2 hours)

### Long-term (Month 1)
7. [ ] Add comprehensive tests (2 days)
8. [ ] Implement CI/CD (1 day)
9. [ ] Setup monitoring (1 day)
```

## 🔄 Re-scan Command
```bash
/shipready:scan --fix
```
Automatically fixes detected issues where possible.

---

**This scan ensures all 8 shipready dimensions can be validated:**
- ✅ Security - Identifies vulnerabilities
- ✅ Database - Checks schema quality
- ✅ Error Handling - Validates error patterns
- ✅ API Design - Reviews API structure
- ✅ Environment - Verifies configuration
- ✅ Performance - Detects bottlenecks
- ✅ Frontend - Checks UI completeness
- ✅ DevOps - Validates deployment readiness