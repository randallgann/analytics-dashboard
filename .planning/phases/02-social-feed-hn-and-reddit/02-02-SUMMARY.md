---
phase: 02-social-feed-hn-and-reddit
plan: 02
subsystem: background-jobs
tags: [ruby, rails, solid-queue, activerecord, sqlite, rails-cache, minitest]

# Dependency graph
requires:
  - phase: 02-social-feed-hn-and-reddit
    plan: 01
    provides: SocialPost model with upsert-compatible schema, HnClient with search_stories, RedditClient with search_posts and typed errors
  - phase: 01-foundation-github-pipeline
    plan: 02
    provides: DataRetentionJob with RETENTION_DAYS constant and delete_all pattern, GithubMetricJob test double patterns (allocate + define_singleton_method + singleton_class.remove_method in ensure)
provides:
  - HnSocialJob background job fetching HN posts via HnClient and upserting into SocialPost with platform 'hn'
  - RedditSocialJob background job fetching Reddit posts via RedditClient and upserting into SocialPost with platform 'reddit'
  - Both jobs write error state to Rails.cache on failure (6-hour TTL) and clear it on success — enables UI to distinguish empty vs failed fetch
  - DataRetentionJob extended to prune SocialPost records with published_at older than 30 days
  - HnSocialJob and RedditSocialJob scheduled every 2 hours in config/recurring.yml via Solid Queue
affects:
  - 02-03  # dashboard UI reads Rails.cache keys social_fetch_error:hn and social_fetch_error:reddit to show platform error states

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "SocialPost.upsert(attrs, unique_by: [:platform, :external_id]) pattern — updates score/comment_count on re-fetch, avoids stale data"
    - "Rails.cache swap in tests — set Rails.cache = ActiveSupport::Cache::MemoryStore.new in test, restore in ensure — enables cache assertions against NullStore test environment"
    - "Job error isolation: known transient errors (FetchError, AuthError, RateLimitError) caught and silenced; StandardError re-raised for Solid Queue retry"
    - "6-hour cache TTL for fetch errors — auto-clears stale errors even if job silently recovers"

key-files:
  created:
    - app/jobs/hn_social_job.rb
    - app/jobs/reddit_social_job.rb
    - test/jobs/hn_social_job_test.rb
    - test/jobs/reddit_social_job_test.rb
  modified:
    - app/jobs/data_retention_job.rb
    - config/recurring.yml
    - test/jobs/data_retention_job_test.rb

key-decisions:
  - "Rails.cache swap in tests — NullStore in test environment discards all writes; swap to MemoryStore in individual tests that need cache assertions, restore in ensure block"
  - "SocialPost.upsert with unique_by — mandatory for score/comment_count freshness; find_or_create_by would leave stale data on re-fetch (RESEARCH.md finding)"
  - "FetchError silenced, StandardError re-raised — transient network errors should not trigger Solid Queue retry backoff; unexpected errors should"
  - "AuthError silenced for Reddit — missing credentials is a known pre-deployment state; HN feed must work independently without Reddit configured"
  - "6-hour cache TTL for error state — stale error auto-clears without requiring a successful fetch if the issue was transient"

patterns-established:
  - "Rails.cache = ActiveSupport::Cache::MemoryStore.new swap pattern — enables cache assertions in NullStore test environment"

requirements-completed: [HN-04, RDT-04]

# Metrics
duration: 3min
completed: 2026-02-24
---

# Phase 2 Plan 2: Social Fetch Jobs Summary

**HnSocialJob and RedditSocialJob upserting into SocialPost via platform-isolated background jobs, error state propagated to Rails.cache for UI, DataRetentionJob extended, both jobs scheduled every 2 hours — 71 tests all passing**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-24T02:24:30Z
- **Completed:** 2026-02-24T02:27:37Z
- **Tasks:** 2 of 2
- **Files modified:** 7

## Accomplishments
- HnSocialJob at `app/jobs/hn_social_job.rb` fetching HN posts via HnClient and upserting into SocialPost; FetchError silenced with cache write; StandardError re-raised
- RedditSocialJob at `app/jobs/reddit_social_job.rb` fetching Reddit posts via RedditClient; AuthError/FetchError/RateLimitError all silenced with cache write; StandardError re-raised
- Both jobs write `Rails.cache.write(FETCH_ERROR_KEY, e.message, expires_in: 6.hours)` on failure and `Rails.cache.delete(FETCH_ERROR_KEY)` on success — UI can distinguish error vs empty
- DataRetentionJob extended to prune SocialPost records where `published_at < 30-day cutoff`
- config/recurring.yml updated with `hn_social_fetch` and `reddit_social_fetch` entries (every 2 hours, queue: default)
- 11 new tests (6 HN + 5 Reddit) + 2 new DataRetentionJob tests = 71 total passing (up from 50)

## Task Commits

Each task was committed atomically:

1. **Task 1: HnSocialJob and RedditSocialJob with upsert logic, error caching, and tests** - `5409c03` (feat)
2. **Task 2: Extend DataRetentionJob for SocialPost pruning and update recurring.yml** - `8617740` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified
- `app/jobs/hn_social_job.rb` - Background job fetching HN posts, upserting via SocialPost.upsert, error state to cache
- `app/jobs/reddit_social_job.rb` - Background job fetching Reddit posts, upserting, error state to cache for all Reddit error types
- `app/jobs/data_retention_job.rb` - Extended with SocialPost.where("published_at < ?", cutoff.beginning_of_day).delete_all
- `config/recurring.yml` - Added hn_social_fetch and reddit_social_fetch (every 2 hours)
- `test/jobs/hn_social_job_test.rb` - 6 tests: record creation, upsert idempotency, FetchError isolation, cache write, cache clear, log output
- `test/jobs/reddit_social_job_test.rb` - 5 tests: record/subreddit creation, AuthError isolation, AuthError cache write, FetchError cache write, cache clear
- `test/jobs/data_retention_job_test.rb` - Added 2 SocialPost pruning tests; updated log regex for dual-model message format

## Decisions Made
- **Rails.cache swap in tests**: Test environment uses NullStore which discards all writes. Solution: `Rails.cache = ActiveSupport::Cache::MemoryStore.new` before the test, restore in ensure. This avoids changing test.rb globally (which would affect all tests) and keeps cache tests isolated.
- **SocialPost.upsert mandatory**: Using find_or_create_by would leave stale scores/comment_counts on re-fetch. upsert with unique_by ensures freshness on every run.
- **FetchError silenced, StandardError re-raised**: Network/API errors are transient — job runs again in 2 hours. Unexpected Ruby errors should trigger Solid Queue retry backoff.
- **AuthError silenced for Reddit**: Missing Reddit credentials is an expected pre-deployment state. HN feed must work without Reddit configured.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Rails.cache NullStore discards writes in test environment**
- **Found during:** Task 1 (HnSocialJob tests)
- **Issue:** config/environments/test.rb sets `config.cache_store = :null_store`. All `Rails.cache.write` calls silently discard values. Cache assertion tests were failing with `Expected: "timed out"`, `Actual: nil`.
- **Fix:** Added `original_cache = Rails.cache; Rails.cache = ActiveSupport::Cache::MemoryStore.new` at the start of each cache-related test, with `Rails.cache = original_cache` in the ensure block. No changes to test.rb (keeps NullStore as default, MemoryStore only in specific tests).
- **Files modified:** test/jobs/hn_social_job_test.rb, test/jobs/reddit_social_job_test.rb
- **Verification:** All 6 HN + 5 Reddit tests pass; full suite 71 tests green
- **Committed in:** `5409c03` (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - Bug)
**Impact on plan:** Essential for correctness — cache tests would be vacuously passing without the swap. No scope creep.

## Issues Encountered
None beyond the NullStore cache issue documented above.

## User Setup Required
None additional — Reddit OAuth2 credentials setup was documented in 02-01-SUMMARY.md.

## Next Phase Readiness
- Both social fetch jobs are deployed-ready; HN runs without credentials, Reddit gracefully handles missing credentials
- Rails.cache keys `social_fetch_error:hn` and `social_fetch_error:reddit` are ready for Plan 03 UI to read
- SocialPost table will be populated on next job run (or immediately via `HnSocialJob.perform_now`)
- All 71 tests passing, schema stable, fixtures unchanged

---
*Phase: 02-social-feed-hn-and-reddit*
*Completed: 2026-02-24*

## Self-Check: PASSED

All created files exist and all task commits verified present in git log.

| Check | Result |
|-------|--------|
| app/jobs/hn_social_job.rb | FOUND |
| app/jobs/reddit_social_job.rb | FOUND |
| app/jobs/data_retention_job.rb | FOUND |
| config/recurring.yml | FOUND |
| test/jobs/hn_social_job_test.rb | FOUND |
| test/jobs/reddit_social_job_test.rb | FOUND |
| .planning/phases/02-social-feed-hn-and-reddit/02-02-SUMMARY.md | FOUND |
| Commit 5409c03 (Task 1) | FOUND |
| Commit 8617740 (Task 2) | FOUND |
