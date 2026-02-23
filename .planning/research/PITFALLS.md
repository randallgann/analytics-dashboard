# Pitfalls Research

**Project:** OpenClaw Analytics Dashboard — GitHub + Social Media API Integrations
**Researched:** 2026-02-23
**Mode:** Pitfalls (domain-specific)
**Confidence:** HIGH for API tier/rate-limit pitfalls; MEDIUM for SQLite/Solid Queue under load

---

## Critical Pitfalls

### 1. X/Twitter API Free Tier Blocks Search

**The problem:** Search endpoints require the Basic tier ($100/month). The Free tier only allows posting, not reading/searching. Many projects build a Twitter integration and discover at deploy time that it doesn't work.

**Warning signs:**
- Building Twitter integration code without first confirming API tier access
- Testing with a developer account that has elevated permissions not available in production

**Prevention strategy:**
- Make a go/no-go decision on X/Twitter API cost BEFORE writing any code
- Design the dashboard to work fully without Twitter — it's an optional enhancement
- Build behind `ENV["ENABLE_TWITTER"]` feature flag regardless
- If proceeding, use Bearer Token (app-only) auth, not user-context OAuth

**Phase mapping:** Must be resolved in planning/requirements phase, not during implementation.

---

### 2. SQLite Write Contention Under Concurrent Sync Jobs

**The problem:** With `SOLID_QUEUE_IN_PUMA: true` (current `deploy.yml`) and 3 worker threads from `queue.yml` all writing to `production.sqlite3` simultaneously during API syncs, `SQLite3::BusyException` errors will occur. SQLite allows only one writer at a time.

**Warning signs:**
- Multiple background jobs completing API fetches and writing results simultaneously
- `SQLite3::BusyException` in production logs
- Jobs silently failing or retrying infinitely

**Prevention strategy:**
- Enable WAL (Write-Ahead Logging) mode on all SQLite databases BEFORE deploying sync jobs
- Add `database.yml` config: `pragmas: { journal_mode: wal, busy_timeout: 5000 }`
- Stagger job schedules so they don't all run at the same minute
- Consider sequential execution within each job (fetch all, then bulk write once)

**Phase mapping:** WAL mode configuration must be in the FIRST phase, before any sync jobs are implemented. This is a prerequisite, not an afterthought.

---

### 3. GitHub Secondary Rate Limits

**The problem:** GitHub has TWO rate limit systems. The primary (5,000 req/hr with PAT) is well-known. The secondary (abuse detection) limits concurrent requests and rapid sequential requests to the same endpoint. Paginated calls for commits and contributors are especially vulnerable.

**Warning signs:**
- 403 responses with `retry-after` header even when under 5,000 req/hr
- Jobs that work in development but fail in production under load
- Naive retry loops that hammer the API harder after getting rate-limited

**Prevention strategy:**
- Build a rate-limit-aware HTTP client layer (check `X-RateLimit-Remaining` headers)
- Add exponential backoff with jitter on 403/429 responses
- Use conditional requests (`If-None-Match` / ETags) to avoid counting cached responses against limits
- Paginate with delays between pages (100ms minimum)
- Use Octokit's built-in `.rate_limit` before bulk operations

**Phase mapping:** Build the shared HTTP client module in the first implementation phase. All API integrations benefit from it.

---

### 4. Reddit Unauthenticated Endpoints Are Unreliable

**The problem:** Reddit's unauthenticated `.json` endpoints work in development (your home IP, browser User-Agent) but fail in production. Server IPs and bot-like User-Agents get rate-limited aggressively or blocked entirely.

**Warning signs:**
- Reddit integration works locally but returns 429 or empty results in production
- Intermittent failures that look like network issues
- No Reddit OAuth2 credentials configured

**Prevention strategy:**
- Plan for OAuth2 from the start, even if unauthenticated works initially
- Register a Reddit "script" app for OAuth2 credentials
- Send a descriptive `User-Agent` header: `OpenClawDashboard/1.0 (by /u/yourname)`
- Implement OAuth2 token refresh in the Reddit fetcher job
- Rate limit to well under 100 req/min (Reddit's documented limit)

**Phase mapping:** Reddit integration phase should include OAuth2 setup as a required step, not optional.

---

### 5. Hacker News Official API Has No Search

**The problem:** The official HN Firebase API (`hacker-news.firebaseio.com/v0/`) only exposes items by ID. There is no search endpoint. You'd have to download ALL story IDs and filter locally — impractical.

**Warning signs:**
- Attempting to use the Firebase API for keyword search
- Building a full-scan approach that downloads thousands of items

**Prevention strategy:**
- Use the Algolia-backed HN Search API from the start: `https://hn.algolia.com/api/v1/search`
- This is free, unauthenticated, and has been stable for a decade
- Returns `title`, `url`, `points`, `num_comments`, `created_at`, `objectID`

**Phase mapping:** Not a phase-level concern — just use the right API from day one.

---

### 6. YouTube Quota Is Unit-Based, Not Request-Based

**The problem:** YouTube Data API v3 uses a quota unit system. A `search.list` call costs 100 units. The free tier is 10,000 units/day. That means a MAXIMUM of 100 search calls per day. Hourly jobs would consume 2,400 units — already over the limit if making multiple calls per job.

**Warning signs:**
- Running YouTube search jobs every hour and hitting quota by mid-afternoon
- 403 `quotaExceeded` errors from YouTube API
- Jobs succeeding in testing (low volume) but failing in production (accumulated quota)

**Prevention strategy:**
- Run YouTube fetch jobs at most 4x/day (every 6 hours)
- Cache results aggressively — only fetch if cache is older than 6 hours
- Use a single search call per job, not multiple paginated calls
- Monitor quota usage via Google Cloud Console
- Build YouTube integration last — it has the tightest constraints

**Phase mapping:** YouTube should be the LAST social platform integrated. It has the most constraints and lowest data volume.

---

### 7. Unbounded Data Growth Without Retention Policy

**The problem:** Without explicit data retention, the SQLite database grows continuously. Social media posts accumulate, GitHub snapshots pile up. Within months, the database file reaches hundreds of megabytes, degrading query performance and backup speed.

**Warning signs:**
- `storage/production.sqlite3` file size growing steadily
- Dashboard queries getting slower over time
- No `DELETE` or cleanup jobs in the codebase

**Prevention strategy:**
- Use `upsert_all` with external IDs (GitHub node ID, Reddit post ID, HN objectID) to prevent duplicates
- Implement a daily cleanup job that deletes records older than 30 days
- NEVER ship a sync job without its corresponding retention/cleanup job
- Add a model scope: `scope :within_window, -> { where("created_at > ?", 30.days.ago) }`
- Monitor database file size in production

**Phase mapping:** Every phase that adds a data source MUST include the retention job for that source. Pair them — never ship one without the other.

---

## Moderate Pitfalls

### 8. API Credential Management

**The problem:** Hardcoding API keys or committing them to git. Rails credentials help, but the workflow of setting up credentials per environment trips up many projects.

**Prevention strategy:**
- Use `Rails.application.credentials` for all API keys
- Support `ENV` variable fallbacks for Docker/CI environments
- Document the exact credential setup in a non-committed file
- Never log API responses that might contain tokens

---

### 9. Inconsistent Data Models Across Platforms

**The problem:** Each social platform has different engagement metrics (likes vs. upvotes vs. points), different time formats, different ID formats. Without a normalized model, the dashboard code becomes a mess of platform-specific conditionals.

**Prevention strategy:**
- Design a `SocialPost` model with normalized fields: `platform`, `external_id`, `title`, `url`, `author`, `engagement_score`, `comment_count`, `published_at`
- Each platform fetcher normalizes to this schema
- The dashboard only queries `SocialPost` — never platform-specific tables

**Phase mapping:** Data model design should happen in the first phase, before any platform-specific fetcher is built.

---

### 10. Background Job Error Handling

**The problem:** API calls fail. Networks timeout. Rate limits hit. If jobs don't handle errors gracefully, they either retry infinitely (wasting quota) or fail silently (stale data).

**Prevention strategy:**
- Set `retry_on` with exponential backoff and a max retry count (3-5)
- Use `discard_on` for permanent failures (404, 401 — API key revoked)
- Log failures with the API source and error type
- Store `last_successful_fetch_at` per data source to detect staleness
- Show "Data unavailable" in the UI rather than stale data with no warning

**Phase mapping:** Error handling patterns should be established in the first fetcher job and reused across all sources.

---

## Roadmap Implications Summary

| Pitfall | Implication |
|---------|-------------|
| SQLite WAL mode | Must be configured BEFORE any sync jobs deploy |
| Shared HTTP client | Build first — all API integrations depend on it |
| X/Twitter cost | Go/no-go decision before coding; design without it |
| Data model normalization | Design `SocialPost` model before building fetchers |
| Retention jobs | Ship paired with every sync job — never one without the other |
| YouTube quota | Integrate last; run jobs infrequently |
| Reddit OAuth2 | Plan for OAuth2 from the start |

---

## Open Questions

- Will the project fund the X/Twitter Basic API tier ($100/month)?
- What is the target polling interval for each source? This directly determines whether `SOLID_QUEUE_IN_PUMA` is viable or a dedicated job server is needed.
- Should the dashboard show a degraded state per-platform (e.g., "Twitter data unavailable") or hide disabled platforms entirely?
