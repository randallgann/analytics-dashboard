# Project Research Summary

**Project:** OpenClaw Analytics Dashboard — API Integration Milestone
**Domain:** Open-source project analytics + multi-platform social media tracking
**Researched:** 2026-02-23
**Confidence:** MEDIUM

## Executive Summary

The OpenClaw Analytics Dashboard is a single-repo OSS metrics tracker that combines GitHub repository data (stars, forks, issues, PRs, commits, contributors) with social media mention tracking across Reddit, Hacker News, YouTube, and X/Twitter. The existing Rails 8.1 application already has the deployment infrastructure, background job system (Solid Queue), caching (Solid Cache), and charting library (Chartkick/Chart.js) in place. This milestone is about adding the data pipelines — API clients, ingest jobs, normalized data models, and real chart data — that transform the current static placeholder dashboard into a live analytics product.

The recommended approach is a clean three-layer extension: thin API client wrappers in `lib/api_clients/`, background ingest jobs in `app/jobs/`, and two normalized ActiveRecord models (`GitHubMetric` and `SocialPost`) that serve all chart and feed data. The key architectural insight is that only two models are needed: GitHub metrics are numeric time-series (one row per metric type per day) while all social platforms share an identical normalized shape (title, URL, author, engagement score, published_at). This avoids migration sprawl as new platforms are added. Build order is database schema first, then API clients (testable in isolation), then jobs, then aggregation queries, then controllers and views — one vertical slice at a time.

The primary risk is the X/Twitter API: search requires a paid tier ($100/month minimum as of mid-2025) and pricing has been volatile. This is a go/no-go decision that must be made before writing any code, and the dashboard must be designed to work fully without it. The secondary risk is SQLite write contention: with multiple concurrent ingest jobs, WAL mode must be enabled before any sync jobs deploy or `SQLite3::BusyException` errors will occur in production. These are both prerequisites, not implementation details.

---

## Key Findings

### Recommended Stack

The project's existing gems (Faraday, Solid Queue, Solid Cache, Chartkick) cover most needs. Only three new gems are required: `octokit` (~9.x) for the GitHub REST API, `google-apis-youtube_v3` for YouTube Data API v3, and `faraday-retry` for retry middleware shared across all integrations. Hacker News requires no gem at all — the Algolia HN Search API is free, unauthenticated, and stable. Reddit requires only Faraday unless the unauthenticated `.json` endpoint fails in production (server IPs are treated differently than browser IPs), in which case OAuth2 via the `redd` gem is the fallback. X/Twitter is the problem child — the only maintained Ruby gem is `x` (~0.x), but the API requires a paid tier and the gem's maintenance status needs verification.

**Core technologies:**
- `octokit ~9.x`: GitHub REST API client — the unambiguous standard; handles auth, pagination, and rate limit headers automatically
- `google-apis-youtube_v3`: YouTube Data API v3 — official Google-generated client, most reliably maintained option
- `faraday-retry ~2.x`: Retry middleware — standardizes exponential backoff across all Faraday-based integrations
- `faraday ~2.x` (existing): HTTP client for Reddit and HN — already present; no second HTTP library needed
- `solid_queue` (existing): Background job scheduling via `config/recurring.yml` recurring jobs
- `solid_cache` (existing): Cache API responses between job runs to prevent redundant quota consumption

See `.planning/research/STACK.md` for complete gem list, version notes, and pre-implementation verification checklist.

### Expected Features

The dashboard needs three categories of table-stakes features to feel complete. GitHub metrics (star count over time, fork count, open/closed issues, PR activity, commit frequency, contributor count, latest release) are expected by every user of an OSS analytics tool — missing any one of these makes the dashboard feel incomplete. Social tracking table stakes are a card-based feed per platform showing recent posts with engagement metrics, click-through links, platform badges, and a time window label. General dashboard table stakes are a hero metrics row with delta indicators, time-series charts replacing the current placeholders, responsive layout, sub-3-second page loads, and a "last updated" timestamp per data source.

**Must have (table stakes):**
- Star count, fork count, open issues over time (line charts) — primary traction signals every OSS tool shows
- PR activity and commit frequency — "is this project active?" signals
- Contributor count with delta — community growth signal
- Social post card feeds per platform (Reddit, HN, YouTube) — core value proposition
- Engagement metrics + click-through link on every social card — without links, the dashboard is a dead end
- Hero metrics row with delta indicators ("+142 stars today") — users orient here first
- "Last updated" timestamp per section — stale data that looks current is worse than no data

**Should have (differentiators):**
- Recency-weighted engagement ranking across platforms — blended "trending" score vs. pure chronological
- Delta indicators on all GitHub metrics — change vs. baseline is more compelling than raw counts
- Hacker News tracking — HN front page is a major OSS event; Algolia API is free/unauthenticated
- YouTube video tracking — tutorial videos precede star spikes; rarely done in OSS dashboards
- GitHub + social signal correlation view — star spike events alongside mention spikes; uniquely valuable
- OpenGraph embed tags — rich preview when dashboard link is shared on social

**Defer (v2+):**
- X/Twitter feed — API costs money; build the abstraction but don't block the milestone on it
- Cross-platform correlation view — needs both data pipelines stable first; design the data model for it now
- Recency-weighted ranking formula — basic recency sort is fine for v1; blended decay formula is a refinement
- Custom date range picker — requires unbounded storage and complex query UI
- Real-time WebSocket updates — complexity vs. value ratio is poor for OSS metrics

See `.planning/research/FEATURES.md` for complete feature table including anti-features that should not be built.

### Architecture Approach

The system extends the existing Rails MVC monolith with three new layers that sit between the external APIs and the existing controller/view/Chartkick path. API client wrappers live in `lib/api_clients/` (infrastructure, not domain objects), ingest jobs live in `app/jobs/` (one job per data source group, scheduled via Solid Queue recurring config), and two ActiveRecord models (`GitHubMetric`, `SocialPost`) serve all read queries through named model scopes. Controllers remain thin — they query the aggregation layer and assign named instance variables; all API calls happen in background jobs, never in the request path.

**Major components:**
1. **API Clients** (`lib/api_clients/`) — Pure Ruby classes; accept credentials and query params, return normalized hashes, raise typed errors (`RateLimitError`, `AuthError`, `NotFoundError`)
2. **Ingest Jobs** (`app/jobs/`) — `FetchGitHubMetricsJob` (every 6h), `FetchSocialPostsJob` (every 2h), `PruneOldRecordsJob` (daily); jobs call clients, upsert records via `upsert_all`, handle errors with `retry_on`/`discard_on`
3. **ActiveRecord Models** (`app/models/`) — `GitHubMetric` (metric_type + value + recorded_on, unique index on [metric_type, recorded_on]) and `SocialPost` (platform + external_id + normalized fields, unique index on [platform, external_id])
4. **Aggregation Layer** (model scopes) — `GitHubMetric.stars_over_time(days: 30)`, `SocialPost.trending_feed(platform:)` — produce chart-ready arrays and ranked feed lists
5. **Dashboard Controller** — reads from aggregation layer; assigns named instance variables; no API calls, no business logic
6. **Views + Chartkick** — renders time-series charts with pre-built data arrays; social post card partials

See `.planning/research/ARCHITECTURE.md` for complete file map, data flow diagrams, and example code patterns.

### Critical Pitfalls

1. **X/Twitter API tier blocks search** — Search requires the paid Basic tier ($100/month minimum). Make a go/no-go decision before writing any code. Design the dashboard to be fully functional without Twitter. Build behind `ENV["ENABLE_TWITTER"]` regardless.

2. **SQLite WAL mode missing causes write contention** — Multiple concurrent ingest jobs writing to the same SQLite database will produce `SQLite3::BusyException` errors. Enable WAL mode in `database.yml` (`pragmas: { journal_mode: wal, busy_timeout: 5000 }`) before deploying any sync jobs. This is a prerequisite, not an afterthought.

3. **GitHub secondary rate limits** — Beyond the 5,000 req/hour primary limit, GitHub has abuse detection that limits rapid sequential requests. Paginated commits and contributor calls are most vulnerable. Use Octokit's built-in rate limit checking, add 100ms delays between pages, and use ETags for conditional requests.

4. **Reddit unauthenticated endpoints fail in production** — Server IPs with bot-like User-Agents get rate-limited or blocked. The unauthenticated `.json` endpoint that works locally often fails in production. Plan for OAuth2 from the start; don't treat it as a fallback.

5. **YouTube quota is unit-based, not request-based** — A `search.list` call costs 100 units. The free tier is 10,000 units/day = 100 searches max. Run YouTube fetch jobs at most 4x/day and integrate YouTube last because of these constraints.

6. **Data growth without retention policy** — Without explicit pruning, SQLite grows unboundedly. Every data source phase must pair a sync job with a retention cleanup job. Never ship one without the other.

See `.planning/research/PITFALLS.md` for complete pitfall analysis including moderate-severity issues (credential management, inconsistent data models, job error handling).

---

## Implications for Roadmap

Based on cross-research synthesis, the following phase structure is recommended. The architecture research explicitly defines build order dependencies; the pitfalls research defines what must be done before anything else; the features research defines what belongs in MVP vs. later phases.

### Phase 1: Foundation — Infrastructure and GitHub Data Pipeline

**Rationale:** Every subsequent phase depends on the database schema and the shared HTTP infrastructure. SQLite WAL mode must be configured before any sync jobs run. The GitHub data pipeline should be the first complete vertical slice because GitHub credentials are straightforward, the API is well-documented, the quota is generous (5,000 req/hr), and it proves the full stack works end-to-end before tackling the more volatile social APIs.

**Delivers:** Working GitHub data pipeline with real data in charts; WAL mode protecting against write contention; shared API client base class with typed errors and retry logic; data retention job pattern established.

**Addresses:**
- Hero metrics row (stars, forks, open issues with deltas)
- Star count over time, fork count over time (line charts replacing placeholders)
- Open/closed issue activity
- Commit frequency
- Contributor count
- Latest release display
- "Last updated" timestamp for GitHub section

**Avoids:** SQLite write contention (WAL mode), GitHub secondary rate limits (shared HTTP client with backoff), unbounded data growth (PruneOldRecordsJob paired from day one)

**Stack:** `octokit ~9.x`, `faraday-retry ~2.x`, `solid_queue` recurring config

**Research flag:** Standard patterns — no phase-level research needed. Rails + Octokit is well-documented.

---

### Phase 2: Social Pipeline — Hacker News and Reddit

**Rationale:** Hacker News is the easiest social integration (free, unauthenticated Algolia API, no credentials required) and proves the `SocialPost` model and feed UI work. Reddit follows because it has moderate complexity (OAuth2 required in production despite the unauthenticated option appearing to work locally). Both platforms together give a multi-platform feed with real data before tackling the more constrained APIs.

**Delivers:** Social post card feed UI; `SocialPost` model and migrations; HN and Reddit fetchers with OAuth2; `FetchSocialPostsJob` architecture with per-platform error isolation; social data retention job.

**Addresses:**
- Recent posts feed per platform (HN, Reddit)
- Engagement metrics + click-through links on social cards
- Platform badges and time window labels
- "Last updated" timestamp for social sections
- Chronological feed sorting (engagement-weighted ranking is Phase 4)

**Avoids:** Reddit OAuth2 surprise in production (build OAuth2 from the start), inconsistent data model (normalize all platforms to `SocialPost` schema before adding any platform), per-platform error isolation (one platform failing must not break others)

**Stack:** Faraday (existing), Reddit OAuth2 app credentials, HN Algolia API (no credentials)

**Research flag:** Reddit OAuth2 setup may benefit from a brief research-phase pass to confirm current API terms, app registration flow, and rate limit documentation. HN is standard patterns.

---

### Phase 3: YouTube Integration

**Rationale:** YouTube is explicitly the most constrained social platform (100 search calls/day free tier cap) and should be integrated after the social feed architecture is proven. The `SocialPost` model already handles it; only the fetcher and scheduling need to respect the tight quota constraints.

**Delivers:** YouTube video cards in the social feed; quota-aware job scheduling (4x/day maximum); Solid Cache integration to prevent redundant quota consumption.

**Addresses:**
- YouTube video tracking (tutorial videos that precede star spikes)

**Avoids:** YouTube quota exhaustion (4x/day schedule, aggressive caching, single search call per job run)

**Stack:** `google-apis-youtube_v3`, `solid_cache` (existing) for quota preservation

**Research flag:** Standard patterns, but verify current free tier quota limits before implementation. The 10,000 units/day figure should be confirmed against current Google Cloud Console settings.

---

### Phase 4: Dashboard Polish — Engagement Ranking, Deltas, and Sharing

**Rationale:** With all data pipelines running and real data in the database, this phase upgrades the presentation layer. Recency-weighted engagement ranking, delta indicators, and OpenGraph embed tags are all low-to-medium complexity features that require real data to validate. They should come after the pipelines are stable, not before.

**Delivers:** Recency-weighted trending score across all social platforms; delta indicators on all GitHub hero metrics (7-day and 30-day changes); OpenGraph embed tags for link sharing; responsive layout refinements.

**Addresses:**
- Recency-weighted engagement ranking (score = engagement / age_hours^decay_factor)
- Delta indicators on all metrics
- OpenGraph embed for sharing
- Responsive layout for mobile viewers

**Avoids:** Premature optimization — blended ranking formula is complex and must be tuned against real engagement data distributions, not synthetic test data.

**Stack:** No new dependencies; pure Rails/Ruby logic

**Research flag:** Standard patterns. No research-phase needed.

---

### Phase 5: X/Twitter Integration (Conditional)

**Rationale:** X/Twitter must not block any other phase. This phase is explicitly gated on a go/no-go decision about API tier costs. If the Basic tier ($100/month) is approved, implement last because the API is the most volatile and least reliable of the five. If not approved, skip and design the dashboard to show "Twitter data unavailable" gracefully.

**Delivers:** X/Twitter post cards in the social feed (if API access approved); otherwise, graceful degraded state with clear "not configured" messaging.

**Addresses:** X/Twitter mentions tracking

**Avoids:** API cost surprise (decision made in requirements, not implementation), feature entanglement (all other phases complete and working without this one)

**Stack:** `x` gem (~0.x) — verify maintenance status before implementing; fallback to raw Faraday HTTP if gem is abandoned

**Research flag:** Requires research-phase pass to confirm: current API tier pricing, whether Bearer token app-only search is available, gem maintenance status. Do not implement without this verification.

---

### Phase Ordering Rationale

- **Schema before anything:** Database migrations must exist before any model, job, or query can be written. This is a hard dependency.
- **Shared HTTP infrastructure first:** The rate-limit-aware client base class and `faraday-retry` middleware benefit every subsequent API integration. Build once, reuse everywhere.
- **One vertical slice before expanding:** GitHub end-to-end (schema → client → job → queries → controller → view) before touching social. This gives a demo-able, testable slice faster than building all clients first.
- **Hacker News before Reddit:** Zero-credential integration proves the `SocialPost` model and social card UI work before introducing OAuth2 complexity.
- **YouTube after social architecture is proven:** The quota constraints make YouTube less forgiving of architectural rework. Integrate it into a stable architecture.
- **Polish after pipelines:** Engagement ranking and delta indicators require real data distributions to validate correctness.
- **X/Twitter last and conditional:** Never let an uncertain, expensive API gate other deliverables.

### Research Flags

Phases needing deeper research during planning:
- **Phase 2 (Reddit):** Reddit API terms, current OAuth2 app registration flow, and rate limit documentation should be verified before implementation. The 2023 policy changes affected third-party access significantly.
- **Phase 3 (YouTube):** Confirm current free tier quota and whether `google-apis-youtube_v3` auto-paginating behavior affects unit consumption.
- **Phase 5 (X/Twitter):** Full research-phase pass required. API tier, pricing, Bearer token search availability, and gem maintenance status must all be verified. Do not implement without this.

Phases with standard patterns (skip research-phase):
- **Phase 1 (GitHub + Foundation):** Octokit + Rails + Solid Queue is extremely well-documented. Standard patterns apply.
- **Phase 4 (Polish):** Pure Rails/Ruby work with no external dependencies. Standard patterns apply.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | MEDIUM | Octokit and HN Algolia are HIGH confidence. YouTube official client is MEDIUM. X/Twitter gem and Reddit gem maintenance status are LOW. All versions must be verified on RubyGems.org before implementation. |
| Features | HIGH | Table stakes features are grounded in stable OSS analytics norms. Anti-features are grounded directly in project constraints. Only differentiator gap analysis is MEDIUM (competitor landscape may have shifted). |
| Architecture | HIGH | Rails MVC + ActiveJob + SQLite + model scopes is extremely well-established. The two-model design (GitHubMetric + SocialPost) is a clean, proven pattern. Solid Queue recurring config format should be verified against current docs. |
| Pitfalls | HIGH | API-tier pitfalls (X/Twitter, YouTube quota) are well-documented and independently verifiable. SQLite WAL mode for concurrent writers is a known, documented Rails pattern. Reddit production behavior is based on well-reported community experience. |

**Overall confidence:** MEDIUM

### Gaps to Address

- **X/Twitter API cost:** This is the single largest unresolved question. The go/no-go decision must happen during requirements definition, not planning. If proceeding, verify current tier pricing, Bearer token search availability, and `x` gem maintenance status before Phase 5 is scoped.

- **Reddit unauthenticated vs. OAuth2:** Test the unauthenticated `.json` endpoint from a server IP early. If it works reliably, Reddit integration is simpler. If it blocks, OAuth2 is required from day one. Do not assume dev behavior predicts production behavior.

- **Solid Queue recurring.yml format:** The exact YAML format for recurring jobs should be verified against current Solid Queue documentation before writing `config/recurring.yml`. The format has evolved across versions.

- **GitHub stargazer history depth:** The GitHub API's `Accept: application/vnd.github.star+json` endpoint for star timestamps has pagination limits. Verify how far back history is accessible with a PAT before designing the historical data model.

- **SQLite WAL mode with Cloud Run:** Verify that the existing Cloud Run deployment writes SQLite to a persistent volume that survives container restarts. WAL mode requires the WAL file to persist alongside the main database file.

---

## Sources

### Primary (HIGH confidence)
- HN Algolia Search API (https://hn.algolia.com/api) — free, unauthenticated, stable for a decade; recommended for all HN search
- GitHub REST API v3 (https://docs.github.com/en/rest) — stable, well-documented; 5,000 req/hr with PAT
- Rails 8.1 ActiveJob documentation — established patterns for job scheduling, retry, and discard
- SQLite3 upsert_all with unique_by — Rails 6+ stable API; directly applicable

### Secondary (MEDIUM confidence)
- Octokit Ruby gem (https://github.com/octokit/octokit.rb) — unambiguous standard for GitHub REST in Ruby; verify version 9.x on RubyGems.org
- Google APIs Ruby client (https://github.com/googleapis/google-api-ruby-client) — official Google-generated; verify `google-apis-youtube_v3` current version
- YouTube Data API v3 (https://developers.google.com/youtube/v3/docs/search/list) — stable but quota is real; verify free tier limits
- Reddit API documentation (https://www.reddit.com/dev/api/) — policy changed in 2023; verify current OAuth2 requirements
- Solid Queue recurring job configuration — verify `recurring.yml` format against current Solid Queue docs
- Faraday retry middleware (https://rubygems.org/gems/faraday-retry) — standard middleware; verify current version

### Tertiary (LOW confidence)
- X/Twitter API (https://developer.twitter.com) — access tiers and pricing change frequently; must be verified before any implementation decision
- `x` Ruby gem (https://github.com/sferik/x-ruby) — verify current maintenance status; build behind feature flag regardless
- `redd` Reddit gem — maintenance status uncertain as of August 2025; treat as fallback to raw Faraday

---
*Research completed: 2026-02-23*
*Ready for roadmap: yes*
