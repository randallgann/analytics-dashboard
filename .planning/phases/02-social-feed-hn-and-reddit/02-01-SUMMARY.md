---
phase: 02-social-feed-hn-and-reddit
plan: 01
subsystem: database
tags: [ruby, rails, activerecord, sqlite, net-http, json, oauth2, algolia]

# Dependency graph
requires:
  - phase: 01-foundation-github-pipeline
    provides: GithubClient typed-error pattern, GitHubMetric model pattern, define_singleton_method test pattern
provides:
  - SocialPost ActiveRecord model with PLATFORMS constant, validations, scopes (for_platform, top_posts, last_30_days, recent_first), class method last_fetched_at, instance methods hn?, reddit?, hn_discussion_url
  - social_posts SQLite table with unique index on [platform, external_id] and indexes on platform and published_at
  - HnClient service using Net::HTTP against hn.algolia.com/api/v1/search_by_date with normalize(), URL fallback to HN discussion URL for Ask HN posts
  - RedditClient service with OAuth2 client_credentials token fetch, search against oauth.reddit.com/search, normalize() converting created_utc to UTC Time
affects:
  - 02-02  # sync jobs will call HnClient.search_stories and RedditClient.search_posts, persist via SocialPost
  - 02-03  # dashboard UI will query SocialPost model scopes

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Net::HTTP for external API calls — no additional gem needed for simple GET/POST requests"
    - "Always-fresh OAuth2 token pattern: fetch token on each job run, never cache, since token expires in 1 hour but job runs every 2 hours"
    - "URL fallback pattern: HN posts without url field fall back to https://news.ycombinator.com/item?id={objectID} (Ask HN posts)"
    - "allocate pattern for test doubles: RedditClient.allocate skips initialize credential check, allows testing normalize() in isolation"

key-files:
  created:
    - app/models/social_post.rb
    - app/services/hn_client.rb
    - app/services/reddit_client.rb
    - db/migrate/20260224021919_create_social_posts.rb
    - test/models/social_post_test.rb
    - test/services/hn_client_test.rb
    - test/services/reddit_client_test.rb
    - test/fixtures/social_posts.yml
  modified:
    - db/schema.rb

key-decisions:
  - "HN URL fallback to discussion page — hit['url'] || 'https://news.ycombinator.com/item?id={objectID}' — Ask HN posts have no external URL, so the discussion thread is the correct destination"
  - "Always-fresh Reddit token — never cache the OAuth2 token; tokens expire in 1 hour but the sync job runs every 2 hours, so a cached token would always be stale"
  - "All subreddits searched (no restrict_sr) — correct default for discovering OpenClaw mentions across all of Reddit, not just one subreddit"
  - "Static fixture dates (2025-12-15, 2025-12-16) — avoid unique constraint conflicts; same pattern established in Phase 1 github_metrics.yml"

patterns-established:
  - "define_singleton_method on Net::HTTP for HTTP stub in tests — override class method, restore in ensure block"
  - "RedditClient.allocate for normalize unit tests — bypasses initialize so credential loading does not interfere"

requirements-completed: [SOC-01, HN-02, HN-03, RDT-02, RDT-03]

# Metrics
duration: 3min
completed: 2026-02-24
---

# Phase 2 Plan 1: Social Feed Foundation Summary

**SocialPost ActiveRecord model with platform/uniqueness validations, HnClient using Algolia API with Ask HN URL fallback, and RedditClient with OAuth2 client_credentials flow — 50 tests all passing**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-24T02:18:34Z
- **Completed:** 2026-02-24T02:22:00Z
- **Tasks:** 2 of 2
- **Files modified:** 9

## Accomplishments
- SocialPost model at `app/models/social_post.rb` with PLATFORMS constant, 4 validations, 4 scopes, `last_fetched_at` class method, and 3 instance methods (hn?, reddit?, hn_discussion_url)
- SQLite migration creating `social_posts` table with 11 columns, unique composite index on [platform, external_id], and performance indexes on platform and published_at
- HnClient service hitting hn.algolia.com/api/v1/search_by_date, normalizing Algolia hits to SocialPost-compatible hashes, falling back to HN discussion URL for Ask HN posts
- RedditClient service fetching fresh OAuth2 token via client_credentials, searching oauth.reddit.com/search, returning [] on 429 rate limit, raising AuthError when credentials are absent
- 11 model tests + 3 HN service tests + 3 Reddit service tests + 33 existing Phase 1 tests = 50 total passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Create SocialPost model, migration, and tests** - `270f4b9` (feat)
2. **Task 2: Create HnClient and RedditClient services with tests** - `2617b9d` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `app/models/social_post.rb` - SocialPost model with validations, scopes, class and instance methods
- `app/services/hn_client.rb` - HN Algolia API client with normalize() and URL fallback logic
- `app/services/reddit_client.rb` - Reddit OAuth2 client with token fetch, search, and normalize()
- `db/migrate/20260224021919_create_social_posts.rb` - Migration with all columns, constraints, indexes
- `db/schema.rb` - Auto-generated schema reflecting social_posts migration
- `test/models/social_post_test.rb` - 11 model tests covering validations, scopes, class methods, predicates
- `test/services/hn_client_test.rb` - 3 HN service tests: normalize, URL fallback, FetchError on non-200
- `test/services/reddit_client_test.rb` - 3 Reddit service tests: AuthError, normalize, UTC conversion
- `test/fixtures/social_posts.yml` - Static date fixtures (hn_post_one, reddit_post_one)

## Decisions Made
- **HN URL fallback**: `hit["url"] || "https://news.ycombinator.com/item?id=#{hit['objectID']}"` — Ask HN posts lack an external URL; the HN discussion thread is the only meaningful link
- **Always-fresh OAuth2 token**: Never cache the Reddit token. Tokens expire in 1 hour; sync job runs every 2 hours, so a cached token would be expired on the second run
- **All subreddits searched**: Correct default for brand monitoring across all of Reddit — no `restrict_sr` parameter
- **Static fixture dates**: 2025-12-15 and 2025-12-16 avoid unique constraint conflicts between fixture load and test data creation (same pattern from Phase 1)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- Shell defaulted to system Ruby 2.6, which failed with Bundler version mismatch. Resolved by prepending `~/.rubies/ruby-3.3.6-dynamic/bin` to PATH — same Ruby 3.3.6 installation used in Phase 1.

## User Setup Required
Reddit OAuth2 credentials are required before the RedditClient can make authenticated requests in production:

1. Go to https://www.reddit.com/prefs/apps and create a new "script" type application
2. Note the client_id (shown under the app name) and the client_secret
3. Run `EDITOR='nano' bin/rails credentials:edit`
4. Add:
   ```yaml
   reddit:
     client_id: your_client_id_here
     client_secret: your_client_secret_here
   ```
5. Alternatively, set `REDDIT_CLIENT_ID` and `REDDIT_CLIENT_SECRET` environment variables

## Next Phase Readiness
- SocialPost model and both API clients are ready for sync job implementation (Plan 02-02)
- All 50 tests passing, schema applied, fixture data in place
- Reddit OAuth2 credentials need to be set before production sync jobs can run

---
*Phase: 02-social-feed-hn-and-reddit*
*Completed: 2026-02-24*

## Self-Check: PASSED

All created files exist and all task commits verified present in git log.

| Check | Result |
|-------|--------|
| app/models/social_post.rb | FOUND |
| app/services/hn_client.rb | FOUND |
| app/services/reddit_client.rb | FOUND |
| db/migrate/20260224021919_create_social_posts.rb | FOUND |
| test/models/social_post_test.rb | FOUND |
| test/services/hn_client_test.rb | FOUND |
| test/services/reddit_client_test.rb | FOUND |
| test/fixtures/social_posts.yml | FOUND |
| Commit 270f4b9 (Task 1) | FOUND |
| Commit 2617b9d (Task 2) | FOUND |
