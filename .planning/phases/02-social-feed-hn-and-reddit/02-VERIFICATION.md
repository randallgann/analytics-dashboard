---
phase: 02-social-feed-hn-and-reddit
verified: 2026-02-24T18:00:00Z
status: human_needed
score: 5/5 must-have truths verified
re_verification: false
human_verification:
  - test: "Tab switching without page reload"
    expected: "Clicking HN, Reddit, and All buttons switches visible content client-side with no full-page navigation"
    why_human: "Stimulus controller tab behavior requires a browser to execute JavaScript — cannot verify client-side DOM manipulation via grep"
  - test: "Platform badge visual appearance"
    expected: "HN cards show an orange square with 'Y'. Reddit cards show a red square with 'R'. Badges are 28x28px, readable at a glance"
    why_human: "CSS rendering and visual correctness requires browser inspection"
  - test: "Last updated timestamp visibility"
    expected: "After a successful job run, the HN and Reddit tabs each show 'Last updated X ago' text below the tab bar"
    why_human: "Requires a job to have run at least once to populate fetched_at; timestamp display depends on runtime state"
  - test: "Cards link out in a new tab"
    expected: "Clicking a card title opens the original URL in a new browser tab (target=_blank confirmed in template)"
    why_human: "Link behavior (new tab opening) requires browser interaction to confirm"
---

# Phase 2: Social Feed (HN and Reddit) Verification Report

**Phase Goal:** A card-based social feed shows recent Hacker News and Reddit posts mentioning OpenClaw, updated every 2 hours
**Verified:** 2026-02-24T18:00:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Dashboard displays a feed of recent HN posts with title, points, comment count, author, date, and a clickable link | VERIFIED | `render_social_card` helper renders all fields; `@hn_posts = SocialPost.for_platform("hn").top_posts(5)` in controller; template iterates with `render_social_card(post)` |
| 2 | Dashboard displays a feed of recent Reddit posts with title, upvotes, comment count, subreddit, author, date, and a clickable link | VERIFIED | `render_social_card` conditionally includes `r/#{post.subreddit}` for Reddit posts; `@reddit_posts = SocialPost.for_platform("reddit").top_posts(5)` in controller |
| 3 | Each social card shows a platform badge (HN or Reddit) identifying its source | VERIFIED | `dash-social-badge--#{post.platform}` CSS class with "Y" for HN and "R" for Reddit in `dashboard_helper.rb:41-43`; CSS classes `dash-social-badge--hn` (#ff6600) and `dash-social-badge--reddit` (#ff4500) present in `application.css` |
| 4 | Each feed section shows a "last updated" timestamp so stale data is visible | VERIFIED | `@hn_last_updated = SocialPost.last_fetched_at("hn")` and `@reddit_last_updated = SocialPost.last_fetched_at("reddit")` in controller; template renders `Last updated <%= time_ago_in_words(@hn_last_updated) %> ago` per tab |
| 5 | If one platform's fetch job fails, the other platform's feed continues to display normally | VERIFIED | `HnSocialJob` rescues `HnClient::FetchError` without re-raising; `RedditSocialJob` rescues `AuthError`, `FetchError`, and `RateLimitError` without re-raising; each job uses its own isolated cache key (`social_fetch_error:hn` vs `social_fetch_error:reddit`); controller reads each key independently |

**Score:** 5/5 truths verified

---

## Required Artifacts

### Plan 01 Artifacts

| Artifact | Provides | Status | Evidence |
|----------|----------|--------|----------|
| `app/models/social_post.rb` | SocialPost model with platform validation, scopes, class methods | VERIFIED | File exists, 30 lines, contains `validates :platform`, `PLATFORMS`, 4 scopes, `last_fetched_at`, `hn?`, `reddit?`, `hn_discussion_url` |
| `app/services/hn_client.rb` | HN Algolia API client returning normalized post hashes | VERIFIED | File exists, 49 lines, contains `hn.algolia.com`, `normalize`, `FetchError`, URL fallback logic |
| `app/services/reddit_client.rb` | Reddit OAuth2 API client with token fetch and search | VERIFIED | File exists, 104 lines, contains `oauth.reddit.com`, `AuthError`, `RateLimitError`, `fetch_token`, `normalize` |
| `test/models/social_post_test.rb` | Model validation and scope tests | VERIFIED | File exists and all 11 model tests pass |
| `test/services/hn_client_test.rb` | HN client response parsing tests | VERIFIED | File exists and all 3 HN service tests pass |
| `test/services/reddit_client_test.rb` | Reddit client auth and search tests | VERIFIED | File exists and all 3 Reddit service tests pass |

### Plan 02 Artifacts

| Artifact | Provides | Status | Evidence |
|----------|----------|--------|----------|
| `app/jobs/hn_social_job.rb` | Background job fetching HN posts via HnClient | VERIFIED | File exists, 33 lines, contains `HnClient`, `SocialPost.upsert`, `FETCH_ERROR_KEY`, cache write/delete |
| `app/jobs/reddit_social_job.rb` | Background job fetching Reddit posts via RedditClient | VERIFIED | File exists, 41 lines, contains `RedditClient`, `SocialPost.upsert`, `FETCH_ERROR_KEY`, rescues all 3 Reddit error types |
| `app/jobs/data_retention_job.rb` | Extended retention job pruning SocialPost records | VERIFIED | File contains `SocialPost.where("published_at < ?", cutoff.beginning_of_day).delete_all` at line 9 |
| `config/recurring.yml` | Schedule entries for both social fetch jobs | VERIFIED | Contains `hn_social_fetch` (every 2 hours) and `reddit_social_fetch` (every 2 hours) |
| `test/jobs/hn_social_job_test.rb` | Job tests for HN fetch and upsert | VERIFIED | File exists and 6 HN job tests pass |
| `test/jobs/reddit_social_job_test.rb` | Job tests for Reddit fetch and upsert | VERIFIED | File exists and 5 Reddit job tests pass |

### Plan 03 Artifacts

| Artifact | Provides | Status | Evidence |
|----------|----------|--------|----------|
| `app/javascript/controllers/tabs_controller.js` | Stimulus controller for tab switching | VERIFIED | File exists, 27 lines, `static targets`, `connect()`, `select()`, `showTab()` all present |
| `app/controllers/dashboard_controller.rb` | Social post queries, timestamps, fetch error state | VERIFIED | `@hn_posts`, `@reddit_posts`, `@all_posts`, `@hn_last_updated`, `@reddit_last_updated`, `@hn_fetch_error`, `@reddit_fetch_error` all assigned in index action |
| `app/helpers/dashboard_helper.rb` | `render_social_card` helper with HN discussion URL fallback | VERIFIED | Method exists at line 39, contains `render_social_card`, `hn_discussion_url` fallback, subreddit conditional |
| `app/views/dashboard/index.html.erb` | Social section with tabbed card feed, error states, empty states | VERIFIED | Contains `id="social"` at line 229, `data-controller="tabs"`, error-before-empty check in both HN and Reddit tabs, `render_social_card` called 3 times |
| `app/assets/stylesheets/application.css` | Dark-themed social card, tab, and error styles | VERIFIED | Contains `.dash-social-card`, `.dash-social-badge--hn`, `.dash-social-badge--reddit`, `.dash-social-error`, `.dash-social-empty`, `.dash-tab-btn--active` |
| `test/controllers/dashboard_controller_test.rb` | Tests for social section rendering including error state | VERIFIED | 8 new social tests present: nav link, HN title, Reddit title, empty state, HN error state, Reddit error state, error-over-posts precedence |

---

## Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `app/services/hn_client.rb` | `https://hn.algolia.com/api/v1/search_by_date` | Net::HTTP GET with query params | WIRED | `BASE_URL = "https://hn.algolia.com/api/v1"` + `uri.query = URI.encode_www_form(...)` at lines 17-23 |
| `app/services/reddit_client.rb` | `https://oauth.reddit.com/search` | Net::HTTP GET with Bearer token | WIRED | `SEARCH_URL = "https://oauth.reddit.com/search"` + `request["Authorization"] = "Bearer #{token}"` at lines 13, 73 |
| `app/models/social_post.rb` | `db/schema.rb` | ActiveRecord migration | WIRED | `create_table "social_posts"` with all required columns, unique index on `[platform, external_id]`, and indexes on `platform` and `published_at` confirmed in schema |
| `app/jobs/hn_social_job.rb` | `app/services/hn_client.rb` | `HnClient.new.search_stories` | WIRED | `client = HnClient.new` + `posts = client.search_stories` at lines 7-8 |
| `app/jobs/reddit_social_job.rb` | `app/services/reddit_client.rb` | `RedditClient.new.search_posts` | WIRED | `client = RedditClient.new` + `posts = client.search_posts` at lines 7-8 |
| `app/jobs/hn_social_job.rb` | `app/models/social_post.rb` | `SocialPost.upsert` with `unique_by` | WIRED | `SocialPost.upsert(attrs, unique_by: [:platform, :external_id])` at line 19 |
| `app/jobs/hn_social_job.rb` | `Rails.cache` | Cache write on failure, delete on success | WIRED | `Rails.cache.delete(FETCH_ERROR_KEY)` at line 23; `Rails.cache.write(FETCH_ERROR_KEY, ...)` at line 27 |
| `config/recurring.yml` | `app/jobs/hn_social_job.rb` | Solid Queue recurring schedule | WIRED | `hn_social_fetch: class: HnSocialJob, schedule: every 2 hours` at lines 27-30 |
| `app/views/dashboard/index.html.erb` | `app/javascript/controllers/tabs_controller.js` | `data-controller='tabs'` on social section | WIRED | `data-controller="tabs"` at line 234 of view; Stimulus auto-registers from `app/javascript/controllers/` |
| `app/controllers/dashboard_controller.rb` | `app/models/social_post.rb` | `SocialPost.for_platform.top_posts` queries | WIRED | `SocialPost.for_platform("hn").top_posts(5)` and related queries at lines 30-35 of controller |
| `app/controllers/dashboard_controller.rb` | `Rails.cache` | Reading `social_fetch_error:hn` and `social_fetch_error:reddit` | WIRED | `Rails.cache.read("social_fetch_error:hn")` and `Rails.cache.read("social_fetch_error:reddit")` at lines 38-39 |
| `app/views/dashboard/index.html.erb` | `app/helpers/dashboard_helper.rb` | `render_social_card` helper call | WIRED | `render_social_card(post)` called at lines 257, 275, 286 of view |
| `app/helpers/dashboard_helper.rb` | `app/models/social_post.rb` | `post.hn_discussion_url` fallback for nil-URL HN posts | WIRED | `post.url \|\| (post.hn? ? post.hn_discussion_url : "#")` at line 48 of helper |

---

## Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| HN-01 | 02-03 | Dashboard displays recent HN posts mentioning OpenClaw as card feed | SATISFIED | `@hn_posts = SocialPost.for_platform("hn").top_posts(5)` + HN tab renders cards via `render_social_card` |
| HN-02 | 02-01 | Each HN card shows title, points, comment count, author, published date | SATISFIED | `render_social_card` outputs `post.score pts`, `post.comment_count comments`, `post.author`, `time_ago_in_words(post.published_at) ago` |
| HN-03 | 02-03 | Each HN card links to original HN discussion | SATISFIED (with locked decision) | Locked user decision in CONTEXT.md: "Cards link to the original URL the post points to". Implementation links to `post.url` first, falls back to `post.hn_discussion_url` for Ask HN posts. HN discussion URL is always reachable. |
| HN-04 | 02-02 | Background job fetches HN posts via Algolia API every 2 hours | SATISFIED | `HnSocialJob` calls `HnClient.new.search_stories`; scheduled `every 2 hours` in `config/recurring.yml` |
| RDT-01 | 02-03 | Dashboard displays recent Reddit posts mentioning OpenClaw as card feed | SATISFIED | `@reddit_posts = SocialPost.for_platform("reddit").top_posts(5)` + Reddit tab renders cards |
| RDT-02 | 02-01 | Each Reddit card shows title, upvotes, comment count, subreddit, author, published date | SATISFIED | `render_social_card` includes `r/#{post.subreddit}` conditional for Reddit posts plus all other fields |
| RDT-03 | 02-03 | Each Reddit card links to original Reddit post | SATISFIED | `link_to(post.title, card_url, ...)` where `card_url = post.url` for Reddit posts (Reddit posts always have a URL) |
| RDT-04 | 02-02 | Background job fetches Reddit posts via OAuth2 every 2 hours | SATISFIED | `RedditSocialJob` calls `RedditClient.new.search_posts` which fetches fresh OAuth2 token; scheduled `every 2 hours` in `config/recurring.yml` |
| SOC-01 | 02-01 | All social posts stored in normalized SocialPost model | SATISFIED | `social_posts` table with all 11 required columns, unique composite index on `[platform, external_id]`, migration version `20260224021919` applied |
| SOC-02 | 02-03 | Platform badge displayed on each social card | SATISFIED | `dash-social-badge--#{post.platform}` div with "Y"/"R" text in brand colors rendered inside every card |
| SOC-03 | 02-03 | "Last updated" timestamp shown per data source section | SATISFIED | `@hn_last_updated` and `@reddit_last_updated` from `SocialPost.last_fetched_at`; template renders `Last updated <%= time_ago_in_words(@hn_last_updated) %> ago` per tab |

**All 11 requirements satisfied.** No orphaned requirements found.

---

## Test Suite Results

Full suite: **71 tests, 163 assertions, 0 failures, 0 errors, 0 skips**

Phase 2 specific subset: **48 tests, 121 assertions, 0 failures, 0 errors, 0 skips**

Tests cover:
- 11 SocialPost model tests (validations, scopes, class methods, predicates, URL construction)
- 3 HnClient service tests (normalize, URL fallback, FetchError on non-200)
- 3 RedditClient service tests (AuthError on missing credentials, normalize, UTC conversion)
- 6 HnSocialJob tests (record creation, upsert idempotency, FetchError isolation, cache write, cache clear, log output)
- 5 RedditSocialJob tests (record + subreddit creation, AuthError isolation, AuthError cache write, FetchError cache write, cache clear)
- 2 DataRetentionJob social pruning tests (SocialPost records pruned beyond 30 days, preserved within 30 days)
- 8 DashboardController tests (social section heading, nav link, HN title, Reddit title, empty state, HN error state, Reddit error state, error-over-stale-posts precedence)

---

## Anti-Patterns Found

None detected. Scanned all Phase 2 files for TODO/FIXME/PLACEHOLDER comments, empty return stubs, and console.log-only implementations. All files contain substantive implementations.

---

## Human Verification Required

### 1. Tab Switching Without Page Reload

**Test:** Start the dev server (`bin/rails server`), visit `http://localhost:3000`, scroll to the Social section. Click the "Reddit" tab button, then "All", then back to "HN".
**Expected:** Content panel switches immediately with no full-page navigation. URL does not change. The active tab button shows the `dash-tab-btn--active` blue underline.
**Why human:** Stimulus JavaScript tab behavior requires browser execution. The controller code is correct, but client-side DOM toggling cannot be verified by static analysis.

### 2. Platform Badge Visual Appearance

**Test:** With social post data seeded (use `bin/rails runner "SocialPost.create!(platform: 'hn', external_id: 'v1', title: 'Test HN Post', url: 'https://example.com', author: 'user', score: 10, comment_count: 2, published_at: 1.day.ago, fetched_at: Time.current)"`), visit the dashboard.
**Expected:** HN cards show a small orange (#ff6600) square containing "Y". Reddit cards show a red (#ff4500) square containing "R". Badges appear at the left edge of each card and are clearly distinguishable.
**Why human:** CSS rendering and visual correctness of colors and sizing requires browser inspection.

### 3. Last Updated Timestamp Visibility

**Test:** Run `HnSocialJob.perform_now` (requires no Reddit credentials — HN has no auth), then visit the dashboard HN tab.
**Expected:** "Last updated less than a minute ago" appears below the tab buttons in small muted text.
**Why human:** The timestamp only appears after `@hn_last_updated` is non-nil, which requires a job to have run and written a `fetched_at` value. Requires runtime execution.

### 4. Ask HN URL Fallback in Browser

**Test:** Seed a post with no URL: `bin/rails runner "SocialPost.create!(platform: 'hn', external_id: 'asktest', title: 'Ask HN: OpenClaw feedback?', url: nil, author: 'asker', score: 5, comment_count: 1, published_at: 1.day.ago, fetched_at: Time.current)"`. Visit the HN tab and hover or right-click the card title.
**Expected:** The link destination is `https://news.ycombinator.com/item?id=asktest` — not "#" or an empty href.
**Why human:** Link destination requires browser hover/inspection to confirm the rendered `href` value.

---

## Summary

Phase 2 goal is substantively achieved in the codebase. All 5 observable truths verified. All 11 requirement IDs (HN-01 through HN-04, RDT-01 through RDT-04, SOC-01 through SOC-03) are satisfied by real implementations — no stubs, no placeholders, no empty returns found.

The implementation delivers:

- A complete SocialPost ActiveRecord model with the correct schema, validations, and scopes
- HnClient hitting the real Algolia API with URL fallback for Ask HN posts
- RedditClient with OAuth2 token fetch, graceful handling of missing credentials, and rate limit handling
- HnSocialJob and RedditSocialJob with upsert semantics (not find-or-create), per-platform error isolation via Rails.cache, and 2-hour Solid Queue schedules
- DataRetentionJob extended to prune SocialPost records older than 30 days
- Stimulus tabs controller for client-side tab switching
- Full dashboard Social section with HN/Reddit/All tabs, sorted cards, platform badges, per-platform last-updated timestamps, error states distinct from empty states, and sticky nav link
- 71 passing tests with 0 failures

Four items require human visual/browser verification: tab switching behavior, badge visual appearance, last-updated timestamp display, and Ask HN URL fallback confirmation in the browser.

---

_Verified: 2026-02-24T18:00:00Z_
_Verifier: Claude (gsd-verifier)_
