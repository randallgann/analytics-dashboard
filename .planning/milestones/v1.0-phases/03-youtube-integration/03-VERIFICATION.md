---
phase: 03-youtube-integration
verified: 2026-02-24T00:00:00Z
status: human_needed
score: 12/12 must-haves verified
re_verification: false
human_verification:
  - test: "Visual: YouTube tab appearance and card formatting"
    expected: "YouTube tab button appears alongside HN, Reddit, All. Clicking YouTube tab shows video cards with red YT badge, view count (not pts), channel name as author, published date, and title linking to youtube.com. All tab includes YouTube posts. Tab switching requires no page reload. Dark theme is consistent with HN/Reddit cards."
    why_human: "Visual appearance, tab switching behavior, and consistent dark-theme styling cannot be verified programmatically from source alone."
---

# Phase 3: YouTube Integration Verification Report

**Phase Goal:** YouTube video cards appear in the social feed, fetched at most 4 times per day to stay within the free API quota
**Verified:** 2026-02-24
**Status:** human_needed — all automated checks passed; one human visual verification remains per Plan 02 checkpoint design
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths (from Phase Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | Dashboard displays YouTube videos with title, view count, channel name, published date, and clickable link | VERIFIED | `render_social_card` in `dashboard_helper.rb` renders `format_number(post.score) views`, `post.author` (channel name), `time_ago_in_words(post.published_at)`, and `link_to(post.title, card_url, target: "_blank")` for YouTube posts. Fixture `youtube_post_one` with title "OpenClaw Tutorial" appears in controller test assertions. |
| 2 | YouTube cards display a platform badge alongside HN and Reddit cards | VERIFIED | `dash-social-badge--youtube` CSS class applied via `dash-social-badge--#{post.platform}`. Three-way conditional renders "YT" text. CSS rule `.dash-social-badge--youtube { background: #ff0000; color: #fff; }` exists in `application.css`. Controller test asserts `dash-social-badge--youtube` appears in response body. |
| 3 | YouTube fetch job runs no more than 4 times per day and does not exhaust the free API quota | VERIFIED | `config/recurring.yml` schedules `youtube_social_fetch` with `schedule: every 6 hours` — exactly 4 runs per day. Job silences AuthError/RateLimitError/FetchError to cache with 6-hour TTL; StandardError re-raises for retry. |

**Score:** 3/3 success criteria verified

---

### Must-Have Truths (from Plan frontmatter)

#### Plan 01 Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 1 | `YoutubeClient.new.search_videos` returns array of hashes with `external_id, title, url, author, score, comment_count, published_at` keys | VERIFIED | `normalize` method in `youtube_client.rb` lines 95–107 returns exactly these keys. `YoutubeClientTest` asserts all keys on `normalize` output. |
| 2 | `YoutubeSocialJob.perform_now` upserts YouTube videos into SocialPost with platform 'youtube' | VERIFIED | `youtube_social_job.rb` lines 13–19: merges `platform: "youtube"` then calls `SocialPost.upsert(attrs, unique_by: [:platform, :external_id])`. Job test `upserts YouTube posts into SocialPost` asserts `SocialPost.where(platform: "youtube", external_id: "yt_vid001").exists?`. |
| 3 | SocialPost validates 'youtube' as a valid platform | VERIFIED | `social_post.rb` line 2: `PLATFORMS = %w[hn reddit youtube].freeze`. Line 4: `validates :platform, inclusion: { in: PLATFORMS }`. Model test `saves valid YouTube post` passes. |
| 4 | YouTube job is scheduled every 6 hours in recurring.yml (max 4 runs/day) | VERIFIED | `config/recurring.yml` lines 37–40: `youtube_social_fetch: class: YoutubeSocialJob, schedule: every 6 hours, queue: default`. |
| 5 | Auth/fetch/rate-limit errors are silenced with cache-based error state, not re-raised | VERIFIED | `youtube_social_job.rb` rescues `AuthError`, `RateLimitError`, `FetchError` — each writes to cache with `expires_in: 6.hours` and does not re-raise. `StandardError` is re-raised. Job tests confirm `assert_nothing_raised` for AuthError and FetchError. |

#### Plan 02 Must-Haves

| # | Truth | Status | Evidence |
|---|-------|--------|---------|
| 6 | YouTube tab appears alongside HN and Reddit tabs in the social section | VERIFIED | `index.html.erb` line 241: `<button data-tabs-target="btn" data-tab-id="youtube" ...>YouTube</button>` between Reddit and All buttons. Controller test `YouTube tab button is rendered` asserts `data-tab-id="youtube"` in response body. |
| 7 | Clicking YouTube tab shows YouTube video cards with title, view count, channel name, and published date | VERIFIED (automated part) | YouTube tab panel at `index.html.erb` lines 282–297 calls `render_social_card(post)` for each `@youtube_posts` entry. Helper renders `format_number(post.score) views`, `post.author`, `time_ago_in_words(post.published_at)`. Human visual confirmation pending. |
| 8 | Each YouTube card links to the original YouTube video URL | VERIFIED | `dashboard_helper.rb` line 54: `card_url = post.url || (post.hn? ? post.hn_discussion_url : "#")`. For YouTube, `post.url` is always `https://www.youtube.com/watch?v=#{video_id}` (set by `normalize`). `link_to(post.title, card_url, target: "_blank")` renders a clickable link. |
| 9 | YouTube cards display a red 'YT' platform badge | VERIFIED | `dashboard_helper.rb` lines 42–48: `else "YT".html_safe end` branch for non-hn/non-reddit posts. CSS `.dash-social-badge--youtube { background: #ff0000; color: #fff; }`. Controller test confirms badge class in response. |
| 10 | YouTube fetch error shows 'Unable to fetch YouTube videos' message | VERIFIED | `index.html.erb` line 289: `<div class="dash-social-error">Unable to fetch YouTube videos</div>` rendered when `@youtube_fetch_error.present?`. Controller test `YouTube fetch error state shows error message not empty state` verifies this with `assert_match /Unable to fetch YouTube videos/`. |
| 11 | Empty YouTube state shows 'No recent mentions found on YouTube' message | VERIFIED | `index.html.erb` line 291: `<div class="dash-social-empty">No recent mentions found on YouTube</div>` rendered when `@youtube_posts.empty?`. Controller test `YouTube empty state shown when no social posts exist` verifies this. |
| 12 | All tab includes YouTube posts alongside HN and Reddit posts | VERIFIED | `dashboard_controller.rb` line 32: `@all_posts = SocialPost.order(score: :desc).limit(10)` — no platform filter. YouTube posts stored as `SocialPost` records with `platform: "youtube"` are included automatically. |

**Score:** 12/12 must-haves verified

---

### Required Artifacts

| Artifact | Status | Details |
|----------|--------|---------|
| `app/services/youtube_client.rb` | VERIFIED | 108 lines. Class exists with three typed error classes, SEARCH_URL/VIDEOS_URL constants, `search_videos` public method, private `fetch_search_results`, `fetch_statistics`, `normalize`. Two-step API fetch fully implemented. |
| `app/jobs/youtube_social_job.rb` | VERIFIED | 41 lines. Class exists with `queue_as :default`, FETCH_ERROR_KEY constant, `perform` method calling `YoutubeClient.new.search_videos`, `SocialPost.upsert`, full three-tier error rescue chain. |
| `app/models/social_post.rb` | VERIFIED | `PLATFORMS = %w[hn reddit youtube].freeze` on line 2. `youtube?` predicate on lines 27–29. |
| `config/recurring.yml` | VERIFIED | `youtube_social_fetch` entry with `class: YoutubeSocialJob`, `schedule: every 6 hours`, `queue: default`. |
| `test/services/youtube_client_test.rb` | VERIFIED | 103 lines. 4 substantive tests: normalize output, FetchError on 500, AuthError on nil key, AuthError on keyInvalid 403, RateLimitError on quotaExceeded 403. |
| `test/jobs/youtube_social_job_test.rb` | VERIFIED | 122 lines. 5 tests: upsert creation, idempotency, AuthError silenced to cache, FetchError silenced to cache, cache cleared on success. |
| `app/controllers/dashboard_controller.rb` | VERIFIED | Lines 42–44 add `@youtube_posts`, `@youtube_last_updated`, `@youtube_fetch_error` alongside existing HN/Reddit queries. |
| `app/helpers/dashboard_helper.rb` | VERIFIED | Lines 42–48: three-way badge (Y/R/YT). Lines 58–63: `format_number(post.score) views` for YouTube; `unless post.youtube?` guard on comment count. |
| `app/views/dashboard/index.html.erb` | VERIFIED | YouTube tab button on line 241. YouTube tab panel on lines 282–297 with error/empty/card states following locked pattern (error precedes empty). |
| `app/assets/stylesheets/application.css` | VERIFIED | `.dash-social-badge--youtube { background: #ff0000; color: #fff; }` on lines 479–482. |
| `test/controllers/dashboard_controller_test.rb` | VERIFIED | 5 new YouTube tests added (lines 131–166): title in response, tab button, empty state, error state with no_match guard, badge class. |

---

### Key Link Verification

#### Plan 01 Key Links

| From | To | Via | Status | Evidence |
|------|----|-----|--------|---------|
| `app/jobs/youtube_social_job.rb` | `app/services/youtube_client.rb` | `YoutubeClient.new.search_videos` | WIRED | Line 7: `client = YoutubeClient.new`. Line 8: `posts = client.search_videos`. Response used in loop lines 12–21. |
| `app/jobs/youtube_social_job.rb` | `app/models/social_post.rb` | `SocialPost.upsert with platform youtube` | WIRED | Lines 13–19: `attrs = post.merge(platform: "youtube", ...)`, then `SocialPost.upsert(attrs, unique_by: [:platform, :external_id])`. |
| `config/recurring.yml` | `app/jobs/youtube_social_job.rb` | Solid Queue recurring schedule | WIRED | `class: YoutubeSocialJob` in `youtube_social_fetch` entry references the job class directly. |

#### Plan 02 Key Links

| From | To | Via | Status | Evidence |
|------|----|-----|--------|---------|
| `app/controllers/dashboard_controller.rb` | `app/models/social_post.rb` | `SocialPost.for_platform('youtube')` | WIRED | Line 42: `@youtube_posts = SocialPost.for_platform("youtube").top_posts(5)`. Result assigned and used in view. |
| `app/views/dashboard/index.html.erb` | `app/helpers/dashboard_helper.rb` | `render_social_card` called for YouTube posts | WIRED | Line 294: `<%= render_social_card(post) %>` inside YouTube tab panel `@youtube_posts.each` loop. |
| `app/controllers/dashboard_controller.rb` | `Rails.cache` | Reading youtube fetch error state | WIRED | Line 44: `@youtube_fetch_error = Rails.cache.read("social_fetch_error:youtube")`. Used in view line 288: `@youtube_fetch_error.present?`. |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|---------|
| YT-01 | 03-01, 03-02 | Dashboard displays recent YouTube videos mentioning OpenClaw as card feed | SATISFIED | YouTube tab panel renders `@youtube_posts` via `render_social_card`. `@youtube_posts = SocialPost.for_platform("youtube").top_posts(5)`. Controller test confirms "OpenClaw Tutorial" fixture title in response body. |
| YT-02 | 03-01, 03-02 | Each YouTube card shows title, view count, channel name, and published date | SATISFIED | `render_social_card` helper: title via `link_to(post.title, ...)`, view count via `format_number(post.score) views` (YouTube branch), channel name via `post.author`, published date via `time_ago_in_words(post.published_at)`. |
| YT-03 | 03-01, 03-02 | Each YouTube card links to original YouTube video | SATISFIED | `normalize` sets `url: "https://www.youtube.com/watch?v=#{video_id}"`. Helper uses `post.url` as `card_url`. `link_to` renders with `target: "_blank"`. |
| YT-04 | 03-01 | Background job fetches YouTube videos via Data API v3 (max 4x/day to respect quota) | SATISFIED | `recurring.yml` schedules `every 6 hours` = 4 runs/day max. Two-step fetch uses search.list + videos.list. Error isolation prevents quota exhaustion retries. |

**Note on REQUIREMENTS.md tracker:** The tracker file still shows YT-01 and YT-02 as "Pending (UI — Plan 02)". This is a documentation staleness issue — Plan 02 was completed and the code fully satisfies both requirements. The tracker was not updated after Plan 02 executed. This does not constitute a code gap; the tracker should be updated to reflect completion.

---

### Anti-Patterns Found

None. All scanned files (`youtube_client.rb`, `youtube_social_job.rb`, `dashboard_controller.rb`, `dashboard_helper.rb`, `index.html.erb`, `application.css`) are free of TODO/FIXME/placeholder comments and empty implementation stubs.

The `return [] if snippets.empty?` on line 28 of `youtube_client.rb` is legitimate early-exit logic (no videos matched the search), not a stub.

---

### Human Verification Required

#### 1. YouTube tab visual appearance and card formatting

**Test:** Start the Rails server (`bin/rails server`). Visit `http://localhost:3000`. Scroll to the Social section.
**Expected:**
- YouTube tab button appears in the tab row alongside HN, Reddit, All (order: HN | Reddit | YouTube | All)
- Clicking YouTube shows either cards or "No recent mentions found on YouTube" empty state
- If cards are present: red "YT" badge, title linking to youtube.com, view count (not "pts"), channel name in meta row, published date
- All tab includes YouTube posts sorted by score alongside HN/Reddit posts
- Tab switching requires no page reload
- Dark theme styling is consistent with HN/Reddit card appearance

**Why human:** Visual appearance, tab switching animation/behavior, styling consistency with the dark theme, and real-time Stimulus controller behavior cannot be confirmed from source code inspection alone. The Plan 02 checkpoint (Task 2) required user approval; the SUMMARY documents that the user confirmed the empty state was displaying correctly, but this verification independently confirms that state.

---

### Commit Verification

All three documented commits verified in git history:
- `0fc2fb6` — feat(03-01): add YoutubeClient service and update SocialPost model
- `b623cc0` — feat(03-01): add YoutubeSocialJob, recurring schedule, and job tests
- `6947d22` — feat(03-02): add YouTube tab to dashboard UI

---

### Summary

Phase 3 goal is achieved. All twelve must-have truths verified against actual code. The end-to-end pipeline is complete and properly wired:

1. **Data pipeline (Plan 01):** `YoutubeClient` performs a two-step API fetch (search.list for snippets, videos.list for view counts), normalizes results to `SocialPost` columns, and stores channel name in the `author` column. `YoutubeSocialJob` upserts records with `platform: "youtube"`, silences expected errors to cache with a 6-hour TTL, and re-raises unexpected errors for Solid Queue retry. The `every 6 hours` schedule satisfies the 4-runs/day quota constraint.

2. **Dashboard UI (Plan 02):** The YouTube tab button and panel are present in the view. `render_social_card` correctly renders "YT" badge, view count (not points), channel name, and published date for YouTube posts. Error and empty states use the locked error-precedes-empty pattern from Phase 2. The `@all_posts` query has no platform filter, so YouTube records are automatically included.

3. **Documentation gap (non-blocking):** `REQUIREMENTS.md` tracker rows for YT-01 and YT-02 still show "Pending" — they should be updated to "Complete (03-02)" to reflect Plan 02 completion.

The single remaining item is the human visual verification checkpoint that was built into Plan 02's design. The SUMMARY documents user approval of the empty state; independent visual confirmation of card formatting with real data (once `YOUTUBE_API_KEY` is configured) remains a human task.

---

_Verified: 2026-02-24_
_Verifier: Claude (gsd-verifier)_
