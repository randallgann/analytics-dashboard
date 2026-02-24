# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-23)

**Core value:** Anyone can see at a glance how OpenClaw is growing and what people are saying about it
**Current focus:** Phase 2 — Social Feed (HN and Reddit)

## Current Position

Phase: 2 of 4 (Social Feed — HN and Reddit)
Plan: 3 of 3 in current phase (paused at checkpoint — awaiting visual verification)
Status: Active
Last activity: 2026-02-23 — Executing plan 02-03 (Social feed UI); paused at Task 3 visual checkpoint

Progress: [████░░░░░░] 33%

## Performance Metrics

**Velocity:**
- Total plans completed: 4
- Average duration: 14min
- Total execution time: 58min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation-github-pipeline | 3/3 | 55min | 18min |
| 02-social-feed-hn-and-reddit | 1/3 | 3min | 3min |

**Recent Trend:**
- Last 5 plans: 16min, 4min, 35min, 3min
- Trend: variable

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- [Requirements]: X/Twitter deferred to v2 — API search requires $100/month minimum paid tier
- [Requirements]: Reddit OAuth2 required from day one — unauthenticated endpoint unreliable on server IPs
- [Phase 1]: SQLite WAL mode is a prerequisite — must be enabled before any sync jobs deploy or BusyException errors will occur
- [01-01]: Named model file github_metric.rb — required Zeitwerk inflector in config/application.rb and explicit self.table_name to maintain plan-specified naming convention
- [01-01]: Used Search API (is:issue, is:pr) for GitHub issue/PR counts — repository.open_issues_count includes PRs and inflates issue metrics
- [01-01]: Ruby 3.3.6 required --enable-shared flag in ruby-install — static build cannot compile native extensions (bigdecimal, sqlite3)
- [01-01]: Minitest 6.0.1 (Rails 8.1) has no Mock class — use define_singleton_method + subclass pattern for test doubles
- [01-02]: Wrapped stats endpoint calls in safe_call to handle StatsUnavailableError as transient (not re-raise)
- [01-02]: GithubClient.allocate for test doubles avoids credential lookup in tests
- [01-02]: DataRetentionJob log test uses \d+ regex because fixture records are > 30 days old and are also pruned
- [01-03]: Chartkick global dark theme configured via initializer — consistent dark palette across all charts without per-chart options
- [01-03]: Rails 8 controller tests use response body assertions instead of assigns helper (removed in Rails 8)
- [01-03]: jd_to_date helper converts Julian Day Number stored in latest_release_date metric to Ruby Date for display
- [01-03]: Gemfile :windows platform entry removed — invalid platform identifier caused bundler error on macOS/Linux
- [02-01]: HN URL fallback to discussion page — hit["url"] || HN item URL — Ask HN posts lack external URL, discussion thread is correct destination
- [02-01]: Always-fresh Reddit OAuth2 token — never cache; tokens expire in 1 hour but sync job runs every 2 hours
- [02-01]: All subreddits searched (no restrict_sr) — correct default for cross-Reddit brand monitoring

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1]: GitHub stargazer history depth — verify how far back star timestamps are accessible with a PAT before finalizing data model
- [Phase 1]: SQLite WAL mode with Cloud Run — verify WAL file persists on the mounted persistent volume between container restarts
- [Phase 2]: Reddit OAuth2 app credentials required — user must register a Reddit app before Phase 2 can run in production
- [Phase 3]: YouTube quota — confirm current free tier is still 10,000 units/day before scheduling 4x/day jobs

## Session Continuity

Last session: 2026-02-23
Stopped at: 02-03-PLAN.md Task 3 checkpoint — awaiting visual verification of social feed section
Resume file: None
