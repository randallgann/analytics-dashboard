---
phase: 03-youtube-integration
plan: 01
subsystem: api
tags: [youtube, youtube-data-api-v3, background-jobs, solid-queue, social-posts]

# Dependency graph
requires:
  - phase: 02-social-feed-hn-and-reddit
    provides: SocialPost model, upsert pattern, cache error pattern, HnClient/RedditClient reference implementations

provides:
  - YoutubeClient service with two-step API fetch (search.list + videos.list)
  - YoutubeSocialJob upserting YouTube videos into SocialPost
  - "youtube" platform in SocialPost::PLATFORMS with youtube? predicate
  - youtube_social_fetch recurring schedule (every 6 hours)

affects: [03-02-youtube-ui, dashboard-ui, social-feed]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Two-step YouTube fetch: search.list for snippets + videos.list for view counts merged via normalize"
    - "AuthError guard in both initialize (fail-fast) and search_videos (allocate bypass safety)"
    - "Three-tier error isolation: AuthError/RateLimitError/FetchError silenced with 6h cache TTL; StandardError re-raises"

key-files:
  created:
    - app/services/youtube_client.rb
    - app/jobs/youtube_social_job.rb
    - test/services/youtube_client_test.rb
    - test/jobs/youtube_social_job_test.rb
  modified:
    - app/models/social_post.rb
    - config/recurring.yml
    - test/fixtures/social_posts.yml
    - test/models/social_post_test.rb

key-decisions:
  - "Nil api_key guarded in both initialize and search_videos — allocate in tests bypasses initialize, so guard needed in search_videos too"
  - "channel_name stored in author column — no new column needed, semantically correct per RESEARCH.md Pitfall 5 resolution"
  - "YouTube scheduled every 6 hours (not 2 hours like HN/Reddit) — satisfies YT-04 max 4 runs/day quota constraint"
  - "Job count assertion uses existence checks not for_platform count — fixture pre-loads 1 youtube record which would skew total count"

patterns-established:
  - "YoutubeClient follows identical error pattern to HnClient/RedditClient — future platform clients should mirror this"
  - "Job tests use existence assertions (find_by + exists?) rather than total platform count to avoid fixture interference"

requirements-completed: [YT-01, YT-03, YT-04]

# Metrics
duration: 4min
completed: 2026-02-24
---

# Phase 3 Plan 01: YouTube Data Pipeline Summary

**YouTube Data API v3 client with two-step fetch (search.list + videos.list), YoutubeSocialJob upsert into SocialPost, and every-6-hour Solid Queue schedule**

## Performance

- **Duration:** 4 min
- **Started:** 2026-02-24T23:20:34Z
- **Completed:** 2026-02-24T23:24:48Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments

- YoutubeClient service fetches public YouTube videos via search.list (snippet data) then videos.list (view counts), returning normalized hashes matching SocialPost columns
- YoutubeSocialJob upserts YouTube videos with platform "youtube", silences auth/rate-limit/fetch errors to cache, re-raises unexpected errors
- SocialPost model accepts "youtube" platform with youtube? predicate; scheduled every 6 hours satisfying 4-runs/day quota constraint

## Task Commits

Each task was committed atomically:

1. **Task 1: YoutubeClient service, SocialPost model update, and tests** - `0fc2fb6` (feat)
2. **Task 2: YoutubeSocialJob, recurring schedule, and job tests** - `b623cc0` (feat)

**Plan metadata:** (docs commit — created after this summary)

## Files Created/Modified

- `app/services/youtube_client.rb` - YoutubeClient with two-step fetch, typed errors (AuthError, RateLimitError, FetchError)
- `app/jobs/youtube_social_job.rb` - Background job upserting YouTube videos, three-tier error isolation
- `app/models/social_post.rb` - Added "youtube" to PLATFORMS, added youtube? predicate
- `config/recurring.yml` - Added youtube_social_fetch schedule (every 6 hours)
- `test/services/youtube_client_test.rb` - normalize, FetchError, AuthError, RateLimitError tests
- `test/jobs/youtube_social_job_test.rb` - upsert, idempotency, AuthError/FetchError cache, cache-clear tests
- `test/fixtures/social_posts.yml` - Added youtube_post_one fixture (2025-12-17 static dates)
- `test/models/social_post_test.rb` - Added youtube? predicate and platform validation tests

## Decisions Made

- **Nil guard in search_videos:** The `initialize` raises AuthError when api_key is nil (fail-fast). However, tests use `YoutubeClient.allocate` to bypass initialize — so the same nil check must be repeated at the top of `search_videos` to ensure the right error is raised in test doubles. Without it, a `NoMethodError` from Net::HTTP fires instead.
- **author column for channel_name:** Per RESEARCH.md Pitfall 5, no new column needed — channel name maps correctly to author. UI plan (Plan 02) will render it as "Channel: DevChannel".
- **Every 6 hours for YouTube:** HN/Reddit run every 2 hours; YouTube runs every 6 hours to stay within the 10,000 unit/day free quota (4 runs × ~100 units/run leaves substantial margin).
- **Existence assertions in job tests:** `SocialPost.for_platform("youtube").count` includes the `youtube_post_one` fixture, causing count mismatch. Used `where(...).exists?` assertions matching the HN job test pattern.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Added nil api_key guard to search_videos method**
- **Found during:** Task 1 (YoutubeClient tests)
- **Issue:** Test for `AuthError when api_key is nil` used `YoutubeClient.allocate` + `instance_variable_set(@api_key, nil)` — bypasses initialize. Without the guard in search_videos, `Net::HTTP.get_response` raises `NoMethodError` (no singleton stub) instead of `AuthError`.
- **Fix:** Added `raise AuthError, "..." if @api_key.nil?` at top of `search_videos` in addition to the existing guard in `initialize`.
- **Files modified:** `app/services/youtube_client.rb`
- **Verification:** 18 tests pass including the nil api_key test
- **Committed in:** `0fc2fb6` (Task 1 commit)

**2. [Rule 1 - Bug] Fixed job test count assertion to use existence checks**
- **Found during:** Task 2 (YoutubeSocialJob tests)
- **Issue:** `assert_equal SAMPLE_VIDEOS.count, SocialPost.for_platform("youtube").count` expected 2 but got 3 — the `youtube_post_one` fixture is pre-loaded in the test DB.
- **Fix:** Changed to `assert SocialPost.where(platform: "youtube", external_id: "yt_vid001").exists?` matching the HN job test pattern.
- **Files modified:** `test/jobs/youtube_social_job_test.rb`
- **Verification:** 5 job tests pass, 80 total tests pass
- **Committed in:** `b623cc0` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 - Bug)
**Impact on plan:** Both auto-fixes necessary for test correctness. No scope creep.

## Issues Encountered

- System Ruby 2.6 intercepted `bin/rails` before project Ruby 3.3.6 could activate (no shell chruby/rbenv active in non-interactive Bash). Resolved by using direct path `~/.rubies/ruby-3.3.6-dynamic/bin/bundle exec bin/rails test` for all commands. `bundle install` ran once to sync `faraday-retry` which was missing from the -dynamic gem set.

## User Setup Required

**External services require manual configuration before YouTube data fetches will work in production:**

- `YOUTUBE_API_KEY` environment variable — from Google Cloud Console -> APIs & Services -> Credentials -> Create API Key, restricted to YouTube Data API v3
- Enable YouTube Data API v3 in Google Cloud Console -> APIs & Services -> Library -> search "YouTube Data API v3" -> Enable

Without this key, `YoutubeSocialJob` will log an AuthError and write to cache on each run — the dashboard will show an error state but will not crash.

## Next Phase Readiness

- YouTube data pipeline complete — Plan 02 (YouTube UI) can now render `SocialPost.for_platform("youtube")` records
- `youtube?` predicate and `author` column (channel name) available for card rendering
- Error state cache key `social_fetch_error:youtube` available for dashboard error banner

---
*Phase: 03-youtube-integration*
*Completed: 2026-02-24*
