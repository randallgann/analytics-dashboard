# Codebase Concerns

**Analysis Date:** 2026-02-23

## Configuration & Security Issues

**Hardcoded Production Defaults:**
- Issue: Production mailer configuration uses `example.com` as default host instead of environment variable
- Files: `config/environments/production.rb` (line 61)
- Impact: Email links in production will point to incorrect domain, breaking user functionality and trust
- Fix approach: Replace hardcoded host with `ENV.fetch("MAIL_HOST", "example.com")` and document required environment variable

**Incomplete Deployment Configuration:**
- Issue: `config/deploy.yml` contains hardcoded placeholder IP `192.168.0.1` for web servers and `localhost:5555` for container registry
- Files: `config/deploy.yml` (lines 9-27)
- Impact: Deployment will fail or deploy to wrong target; registry assumes local development setup
- Fix approach: Extract to environment variables or template system; document required deployment parameters before production use

**Missing Content Security Policy:**
- Issue: Content Security Policy is completely disabled (all commented out in `config/initializers/content_security_policy.rb`)
- Files: `config/initializers/content_security_policy.rb`
- Impact: Application is vulnerable to XSS and injection attacks; third-party scripts can execute without restriction
- Recommendations: Enable CSP with restrictive defaults; at minimum configure `script-src 'self' 'nonce-*'`, `style-src 'self' 'nonce-*'`

**Host Authorization Disabled:**
- Issue: Host authorization and DNS rebinding protection are commented out (lines 83-89 in `config/environments/production.rb`)
- Files: `config/environments/production.rb`
- Impact: Application vulnerable to Host header attacks and DNS rebinding attacks
- Recommendations: Enable with proper host configuration; at minimum add production domain

## Missing Critical Features

**Incomplete Analytics Dashboard Implementation:**
- What's not implemented: Dashboard controller is empty stub with no data fetching, filtering, or analysis logic
- Files: `app/controllers/dashboard_controller.rb`
- Blocks: Real analytics data display; filtering by date ranges, metrics; user analysis
- Current state: Only static hardcoded example chart visible (Q1-Q4 sales data)

**No Authentication/Authorization:**
- What's missing: No user authentication, role-based access control, or session management configured
- Impact: Dashboard is publicly accessible; no way to restrict data by user; no audit trail
- Security risk: All analytics data exposed to anyone who can access the URL

**No Data Models or Persistence:**
- What's missing: No database models defined for analytics data, events, or users
- Files: `app/models/` contains only `application_record.rb` base class
- Impact: No way to store, query, or track real analytics data; application is read-only UI mockup

## Test Coverage Gaps

**Minimal Test Coverage:**
- What's not tested: Dashboard data fetching, chart rendering, filtering, error handling
- Files: `test/controllers/dashboard_controller_test.rb` (only 1 basic test)
- Risk: Changes to data logic or charts could break silently; no regression detection
- Priority: High - Core functionality has no test coverage

**System Tests Not Implemented:**
- What's not tested: User-facing features, real data flows, JavaScript-driven interactions
- Files: `test/application_system_test_case.rb` exists but unused
- Gap: No tests for chart rendering, data updates, responsive behavior

**No Fixtures/Seeds for Testing:**
- What's missing: No test data factories or seed data generators
- Files: `db/seeds.rb` (9 lines, empty implementation)
- Impact: Integration tests cannot verify data display, filtering, or calculations

## Database & Persistence Concerns

**SQLite in Production:**
- Issue: Using SQLite3 for production database (configured in `config/database.yml` line 29)
- Files: `config/database.yml`, `Dockerfile` (line 19)
- Impact: Limited to single concurrent write; no horizontal scaling; data loss risk with container restarts
- Fix approach: Migrate to PostgreSQL or managed database service for production; keep SQLite for development/test

**Multiple Database Instances Without Migration Plan:**
- Issue: Configuration expects 4 separate SQLite databases in production: main, cache, queue, cable
- Files: `config/database.yml` (lines 26-41)
- Impact: High maintenance burden; complex backup/restore; storage volume must accommodate all four
- Scaling limit: Each database file is single-threaded; poor performance under load

**No Database Migrations Executed:**
- What's missing: No migration files found; no schema versioning
- Files: No `/db/migrate/` directory with any files
- Risk: Cannot track schema changes; cannot roll back changes; no audit trail of schema evolution

## Performance & Scaling Concerns

**Chartkick/Chart.js Bundle Size:**
- Issue: Large vendored JavaScript libraries included without analysis
- Files: `vendor/javascript/Chart.bundle.js` (24,219 lines), `vendor/javascript/chartkick.js` (2,570 lines)
- Impact: Slow initial page load; bundle size not optimized
- Improvement path: Evaluate lighter charting alternatives (e.g., Simple Charts, Chart.js without bundle); lazy-load charts

**No Caching Strategy for Analytics:**
- Issue: No caching layer for computed analytics or aggregated data
- Files: `config/environments/production.rb` (line 50 enables cache, but no usage in controller)
- Impact: Each request recalculates; poor performance with large datasets
- Missing: Cache invalidation strategy, background aggregation jobs

**Solid Queue Job System Enabled But Unused:**
- Issue: Background job queue configured but no jobs defined
- Files: `app/jobs/application_job.rb` (base class only)
- Impact: Application initialization overhead without benefit
- Recommendation: Remove if not needed or define async data processing jobs

## Documentation & Maintainability

**Incomplete README:**
- Issue: README.md is Rails template with no project-specific information
- Files: `README.md`
- Impact: New developers have no setup instructions, architecture overview, or deployment guide
- Missing: Environment variables, database setup, running tests, Cloud Run deployment info

**Deployment Configuration Unclear:**
- Issue: `config/deploy.yml` references "Cloud Run deployment" (from commit message) but uses Kamal (Docker-based tool)
- Files: `config/deploy.yml`
- Confusion: Cloud Run is Google Cloud service, Kamal is for traditional VPS; unclear which is actual target
- Impact: Deployment instructions may be incorrect or incomplete

**No API Documentation:**
- Issue: No documentation of dashboard endpoints, data formats, or expected responses
- Impact: Difficult to extend or integrate with external tools

## Security Best Practices Gaps

**Audit Logging Not Configured:**
- What's missing: No tracking of user actions, data access, or admin changes
- Impact: Cannot detect unauthorized access or data exfiltration
- Recommendation: Log all chart views, data exports, configuration changes with user/IP tracking

**CSRF Protection in Test Only Affects Real Requests:**
- Issue: CSRF protection disabled in test environment (config/environments/test.rb line 29)
- Files: `config/environments/test.rb`
- Impact: May not catch CSRF vulnerabilities before production
- Recommendation: Keep protection enabled in tests; use CSRF tokens in all forms

**No Rate Limiting:**
- What's missing: No protection against brute force, DoS, or API abuse
- Impact: Dashboard could be overwhelmed by automated requests
- Recommendation: Add rate limiting middleware (e.g., Rack::Attack) with IP-based throttling

## Code Quality Issues

**Empty Helper Modules:**
- Issue: `app/helpers/application_helper.rb` and `app/helpers/dashboard_helper.rb` are empty stubs
- Files: `app/helpers/application_helper.rb`, `app/helpers/dashboard_helper.rb`
- Impact: Code organization uncertainty; unclear where view logic should live
- Recommendation: Either remove unused files or populate with actual helper methods

**Stimulus Controllers Minimal:**
- Issue: Only placeholder "hello_controller.js" exists with no dashboard interactivity
- Files: `app/javascript/controllers/hello_controller.js`
- Impact: No client-side state management or interactive features
- Recommendation: Implement Stimulus controllers for chart filtering, data updates if needed

**CSS Assets Unconfigured:**
- Issue: `app/assets/stylesheets/application.css` contains only template boilerplate, no actual styles
- Files: `app/assets/stylesheets/application.css`
- Impact: Dashboard has no custom styling; relies on browser defaults
- Recommendation: Add CSS framework (Tailwind, Bootstrap) or define custom styles for analytics dashboard

## Deployment & Infrastructure Concerns

**Docker Build Assumes RAILS_MASTER_KEY Present:**
- Issue: Dockerfile secrets not documented; build will fail without `RAILS_MASTER_KEY` in credentials
- Files: `Dockerfile` (line 54), `config/deploy.yml` (line 39)
- Impact: Deployment blocked if RAILS_MASTER_KEY not provided
- Fix approach: Document required secret generation; use GitHub Secrets in CI/CD

**Storage Volume Not Configured for Cloud Run:**
- Issue: `config/deploy.yml` uses `analytics_dashboard_storage:/rails/storage` volume mount
- Files: `config/deploy.yml` (lines 68-69)
- Impact: Cloud Run does not support persistent volumes; data will be lost on deployment
- Fix approach: If using Cloud Run, migrate to Cloud Storage for file uploads; use Cloud SQL for database

**Kamal Configuration Incomplete for Production:**
- Issue: Deploy config is skeletal; no health checks configured beyond default `/up` endpoint
- Files: `config/deploy.yml`
- Missing: Deployment strategies, rollback configuration, monitoring integrations, log shipping

## Dependencies at Risk

**Rails 8.1.x - Rapid Release Cadence:**
- Risk: Rails 8.1.0 is recent; will see frequent minor updates and potential breaking changes
- Impact: Regular updates required; dependency churn
- Migration plan: Pin to 8.1.x series; schedule quarterly dependency updates

**Bundler Audit Configuration Generic:**
- Issue: `config/bundler-audit.yml` has placeholder ignore entry that won't catch real CVEs
- Files: `config/bundler-audit.yml`
- Impact: Security vulnerabilities in dependencies may be ignored
- Fix approach: Run `bundler-audit` regularly; actively maintain CVE ignore list with justifications

**No Development Environment Isolation:**
- Issue: No Docker Compose or dev container configuration provided
- Impact: Setup documentation missing; developers may have environment drift
- Recommendation: Add `.devcontainer/devcontainer.json` or `docker-compose.dev.yml`

---

*Concerns audit: 2026-02-23*
