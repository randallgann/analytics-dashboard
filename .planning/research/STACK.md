# Technology Stack

**Project:** OpenClaw Analytics Dashboard — API Integration Milestone
**Researched:** 2026-02-23
**Scope:** Adding GitHub API, X/Twitter API, Reddit API, Hacker News API, and YouTube API to existing Rails 8.1 app

## Important Confidence Note

External tool access was unavailable during this research session. All recommendations are based on training knowledge with a cutoff of August 2025. Version numbers MUST be verified against RubyGems.org before implementation. Confidence levels reflect this constraint.

---

## Recommended Stack

### GitHub API Integration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| octokit | ~9.x | GitHub API v3 client | Official GitHub-maintained Ruby client; handles auth, pagination, rate limiting automatically |
| faraday | ~2.x | HTTP adapter (already present) | Octokit uses Faraday internally; explicit dep enables custom retry/logging middleware |

**Confidence:** MEDIUM — Octokit is the unambiguous standard for GitHub API in Ruby. Version 9.x is the current major line with Ruby 3+ support. Verify exact patch version on RubyGems.org.

**Why not alternatives:**
- `graphql-client` — over-engineered; GitHub REST API v3 covers all needed metrics (stars, forks, issues, PRs, commits, contributors)
- Raw `Net::HTTP` — would require hand-rolling pagination, rate limit handling, and auth that Octokit provides for free
- `github_api` gem — largely unmaintained since pre-2022

**Rate limit strategy:** 5,000 req/hour with PAT. Solid Queue jobs can spread calls across the hour. Use Octokit's built-in `.rate_limit` check before bulk operations.

---

### X/Twitter API Integration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| x (gem) | ~0.x | X API v2 client | Created by the original `twitter` gem author; actively maintained for v2 API as of mid-2025 |

**Confidence:** LOW — X/Twitter API pricing and availability are volatile. Verify the following before implementing:

1. Does `gem "x"` still exist and is actively maintained? (https://rubygems.org/gems/x)
2. What access tier is required for search? As of 2024, Basic tier ($100/month) was required for meaningful search. This may have changed.
3. Is app-only Bearer token auth (no user login) sufficient for public post search?

**Why not alternatives:**
- `twitter` gem (original) — deprecated; targets API v1.1 which is shut down
- Raw HTTP — viable fallback if no gem is maintained

**Critical architecture note:** Build X/Twitter integration behind a feature flag (`ENV["ENABLE_TWITTER"]`). If API costs are prohibitive, disable without breaking other integrations.

---

### Reddit API Integration

**Recommended approach: Unauthenticated JSON endpoint (no gem needed)**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| faraday | ~2.x (existing) | HTTP calls to Reddit JSON API | Reddit exposes public post search as JSON without OAuth for read-only access |

**Confidence:** MEDIUM — Reddit's public `.json` endpoint (e.g., `https://www.reddit.com/search.json?q=openclaw&sort=new`) has been available for years. Verify it's still accessible and not rate-limited for unauthenticated requests.

**If OAuth2 is required:**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| redd | ~1.x | Reddit OAuth2 API client | Most maintained Ruby Reddit gem; supports app-type OAuth |
| oauth2 | ~2.x | Token management | Reddit OAuth2 token refresh handling |

**Confidence:** LOW — `redd` gem maintenance status uncertain as of August 2025. Verify on RubyGems.org.

**Why not alternatives:**
- `snoo` gem — unmaintained
- Other Ruby Reddit gems — abandoned

**Rate limits:** 100 req/min authenticated; much lower unauthenticated. Must send descriptive `User-Agent` header identifying the app.

---

### Hacker News API Integration

**No gem needed.**

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| faraday | ~2.x (existing) | HTTP calls to Algolia HN Search API | Free, unauthenticated, stable since 2014 |

**Confidence:** HIGH — The Hacker News Algolia Search API (`https://hn.algolia.com/api/v1/search?query=openclaw&tags=story`) is free, unauthenticated, and has been stable for a decade. No gem, no API key, no rate limits published.

**Why not the official HN Firebase API:**
- `https://hacker-news.firebaseio.com/v0/` does not support keyword search
- Would require downloading all story IDs and filtering locally — impractical

**Implementation:** Single Faraday call to Algolia endpoint. Returns JSON with `title`, `url`, `points`, `num_comments`, `created_at`, `objectID` (links to HN discussion).

---

### YouTube API Integration

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| google-apis-youtube_v3 | ~0.x | YouTube Data API v3 | Official Google-generated Ruby client; auto-updated from API discovery document; authoritative |

**Confidence:** MEDIUM — Google's auto-generated API clients are the correct long-term choice. Verify current version at https://rubygems.org/gems/google-apis-youtube_v3.

**Alternative (simpler):** For read-only search, a raw Faraday GET with an API key is viable:
`GET https://www.googleapis.com/youtube/v3/search?part=snippet&q=openclaw&type=video&key=API_KEY`

**Why not alternatives:**
- `yt` gem — has had maintenance gaps; official Google gem is more reliable
- `youtube_it` gem — abandoned, targets old API

**API quota:** YouTube Data API v3 is free up to 10,000 units/day. A search costs 100 units. Hourly background jobs = ~2,400 units/day — well within free tier.

---

### HTTP Client (Cross-Cutting)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| faraday | ~2.x | HTTP client across all integrations | Already present via Octokit; use consistently rather than mixing HTTParty, http.rb |
| faraday-retry | ~2.x | Retry middleware | Handles transient 5xx errors and 429 rate limits from all APIs |

**Confidence:** MEDIUM — Faraday 2.x is current; `faraday-retry` is the standard middleware for this use case. Verify versions on RubyGems.org.

---

### Scheduling & Background Jobs (Cross-Cutting)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| solid_queue | existing | Job scheduling and execution | Already installed and configured; use `config/recurring.yml` for cron-like per-API schedules |

**Confidence:** HIGH — Solid Queue 1.x+ supports recurring jobs via `config/recurring.yml`. No additional gem needed. Define one recurring job per data source with appropriate intervals.

---

### Caching (Cross-Cutting)

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| solid_cache | existing | Cache API responses | Already installed; use `Rails.cache.fetch` with TTLs in background jobs to prevent redundant API calls on retries |

**Confidence:** HIGH — Solid Cache is already configured and operational.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| GitHub API | octokit | Raw Faraday | Octokit handles pagination, auth headers, rate limit headers automatically |
| GitHub API | octokit | graphql-client | REST v3 sufficient; GraphQL adds complexity |
| Twitter/X | x gem | Raw HTTP | x gem is the only maintained option; raw HTTP is the fallback |
| Reddit | Unauthenticated JSON | redd gem | OAuth setup is unnecessary if unauthenticated endpoint works |
| Hacker News | Algolia API (no gem) | firebase-admin gem | Official HN Firebase API doesn't support search |
| YouTube | google-apis-youtube_v3 | yt gem | Official Google client is more reliably maintained |
| HTTP Client | faraday (existing) | httparty, http.rb | Faraday already present; no reason to add a second HTTP library |

---

## Gemfile Additions

```ruby
# GitHub API — verify latest version at rubygems.org/gems/octokit
gem "octokit", "~> 9.0"

# HTTP retry middleware — verify at rubygems.org/gems/faraday-retry
gem "faraday-retry", "~> 2.0"

# YouTube Data API v3 — verify at rubygems.org/gems/google-apis-youtube_v3
gem "google-apis-youtube_v3"

# X/Twitter — LOW CONFIDENCE: verify gem exists and API tier requirements
# gem "x"

# Reddit — No gem needed if unauthenticated JSON endpoint works.
# If OAuth2 required, add: gem "redd" (verify maintenance status first)

# Hacker News — No gem needed (Algolia public API, no auth)
```

---

## Pre-Implementation Verification Checklist

- [ ] **X/Twitter:** Confirm current API tier cost. Check if Bearer token app-only search is available on free/basic tier. Build behind `ENABLE_TWITTER` env flag regardless.
- [ ] **Reddit:** Test `https://www.reddit.com/search.json?q=openclaw&sort=new` without auth. If it returns results, no OAuth setup needed.
- [ ] **octokit:** Verify current version at https://rubygems.org/gems/octokit
- [ ] **faraday-retry:** Verify current version at https://rubygems.org/gems/faraday-retry
- [ ] **google-apis-youtube_v3:** Verify current version at https://rubygems.org/gems/google-apis-youtube_v3
- [ ] **Hacker News Algolia:** Confirm `https://hn.algolia.com/api/v1/search?query=test&tags=story` returns results
- [ ] **GitHub PAT:** Confirm no special OAuth scopes needed for public repo metrics

---

## API Credentials Mapping

| API | Credentials Needed | Rails Credentials Key |
|-----|-------------------|-----------------------|
| GitHub | Personal Access Token | `credentials.github.access_token` |
| X/Twitter | Bearer Token | `credentials.twitter.bearer_token` |
| Reddit | Client ID + Secret (if OAuth) | `credentials.reddit.client_id` / `.client_secret` |
| Hacker News | None | — |
| YouTube | API Key | `credentials.youtube.api_key` |

---

## Sources

All recommendations based on training knowledge (cutoff August 2025). Verification required:

- Octokit: https://github.com/octokit/octokit.rb
- x gem: https://github.com/sferik/x-ruby (LOW confidence — verify maintained)
- HN Algolia API: https://hn.algolia.com/api (HIGH confidence — stable)
- YouTube Data API v3: https://developers.google.com/youtube/v3/docs/search/list
- Google APIs Ruby: https://github.com/googleapis/google-api-ruby-client
- Reddit API: https://www.reddit.com/dev/api/ (LOW confidence — volatile)
- RubyGems for all version verification: https://rubygems.org
