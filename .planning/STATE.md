# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-02-23)

**Core value:** Anyone can see at a glance how OpenClaw is growing and what people are saying about it
**Current focus:** Phase 4 — Deployment

## Current Position

Phase: 3 of 4 (YouTube Integration) — COMPLETE
Plan: 2 of 2 in current phase — COMPLETE
Status: Phase 3 complete, ready for Phase 4
Last activity: 2026-02-24 — Completed plan 03-02 (YouTube dashboard UI: tab, video cards, YT badge, view count, empty/error states)

Progress: [████████░░] 75%

## Performance Metrics

**Velocity:**
- Total plans completed: 8
- Average duration: 13min
- Total execution time: 110min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 01-foundation-github-pipeline | 3/3 | 55min | 18min |
| 02-social-feed-hn-and-reddit | 3/3 | 36min | 12min |
| 03-youtube-integration | 2/2 | 19min | 10min |

**Recent Trend:**
- Last 5 plans: 3min, 3min, 30min, 4min, 15min
- Trend: consistently fast

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
- [02-02]: Rails.cache swap in tests — test env uses NullStore; swap to MemoryStore.new in individual tests, restore in ensure — avoids changing global test env config
- [02-02]: SocialPost.upsert mandatory for score/comment_count freshness — find_or_create_by leaves stale data on re-fetch
- [02-02]: AuthError silenced for Reddit — missing credentials is expected pre-deployment; HN must work independently
- [02-02]: 6-hour cache TTL for error state — auto-clears stale errors without requiring successful fetch
- [02-03]: Stimulus tabs use data-tab-id on both button and panel targets — single attribute lookup, no fragile id management
- [02-03]: Error state check precedes empty state check in view — fetch error shows "Unable to fetch" even when stale posts exist
- [02-03]: Single-letter text badges (Y for HN, R for Reddit) in brand-colored squares — no icon library dependency
- [02-03]: render_social_card helper isolates card markup — HN fallback URL logic contained in one tested helper method
- [03-01]: Nil api_key guarded in both initialize and search_videos — allocate in tests bypasses initialize, so guard needed in search_videos too
- [03-01]: channel_name stored in author column — no new column needed, semantically correct per RESEARCH.md Pitfall 5
- [03-01]: YouTube scheduled every 6 hours — satisfies YT-04 max 4 runs/day quota constraint
- [03-01]: Job tests use existence assertions not total platform count — fixture pre-loads 1 youtube record which would skew count assertions
- [03-02]: "YT" badge text distinguishes from HN "Y" badge — two chars vs one, both fit inside 28x28px brand-colored square
- [03-02]: View count label replaces "pts" for YouTube — score column stores view_count, label must match platform semantics
- [03-02]: Comment count suppressed for YouTube (unless post.youtube?) — API always returns 0, "0 comments" on every card is noise
- [03-02]: Error state check precedes empty check in YouTube tab panel — locked decision inherited from Phase 2 (02-03)

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 1]: GitHub stargazer history depth — verify how far back star timestamps are accessible with a PAT before finalizing data model
- [Phase 1]: SQLite WAL mode with Cloud Run — verify WAL file persists on the mounted persistent volume between container restarts
- [Phase 2]: Reddit OAuth2 app credentials required — user must register a Reddit app before Phase 2 can run in production
- [Phase 3]: YouTube API key required — user must create API key in Google Cloud Console and enable YouTube Data API v3 before YoutubeSocialJob will fetch data
- [Phase 3]: YouTube quota — confirmed 10,000 units/day free tier; scheduled at 6 hours (4 runs/day) with ~100 units/run leaves substantial margin

## Session Continuity

Last session: 2026-02-24
Stopped at: Completed 03-02-PLAN.md (YouTube dashboard UI: tab, video cards, YT badge, view count, empty/error states) — Phase 3 complete
Resume file: None
