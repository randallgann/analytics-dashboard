---
phase: 02-social-feed-hn-and-reddit
plan: 03
subsystem: ui
tags: [stimulus, tabs, social-cards, dark-theme, hacker-news, reddit, erb, css]

# Dependency graph
requires:
  - phase: 02-social-feed-hn-and-reddit
    provides: SocialPost model, HnClient, RedditClient, HnSocialJob, RedditSocialJob — the data layer this UI reads from
  - phase: 01-foundation-github-pipeline
    provides: DashboardController index action, dark theme CSS base classes, dash-card/dash-section patterns, time_ago_or_never helper
provides:
  - Stimulus tabs controller (tabs_controller.js) for client-side tab switching without page reload
  - Social feed section on dashboard: HN, Reddit, and All tabs with sorted post cards
  - render_social_card helper with HN discussion URL fallback for Ask HN posts
  - Per-platform error state rendering (Unable to fetch [platform] posts) from Rails.cache
  - Per-platform empty state rendering when no posts and no fetch error
  - "Last updated X ago" timestamp per platform tab
  - CSS for dark-themed social cards, tab nav, badges, error and empty states
  - Controller tests covering social rendering, error state, empty state, and nav link
affects: [03-youtube-channel-metrics, any future social UI work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Stimulus tabs controller with data-tab-id on both btn and tab targets — matching strategy avoids id conflicts
    - Error-before-empty check in ERB — fetch error takes precedence over empty posts (stale posts may exist from prior success)
    - render_social_card helper using content_tag and safe_join — keeps view clean while supporting conditional subreddit display
    - HN discussion URL fallback via post.hn_discussion_url — Ask HN posts without external URL never show dead '#' link

key-files:
  created:
    - app/javascript/controllers/tabs_controller.js
  modified:
    - app/controllers/dashboard_controller.rb
    - app/helpers/dashboard_helper.rb
    - app/views/dashboard/index.html.erb
    - app/assets/stylesheets/application.css
    - test/controllers/dashboard_controller_test.rb

key-decisions:
  - "Stimulus tabs use data-tab-id on both button and panel targets — single attribute lookup, no fragile id management"
  - "Error state check precedes empty state check in view — ensures failed fetch shows error not misleading empty message even when stale posts exist"
  - "Single-letter badge (Y for HN, R for Reddit) in brand-colored 28x28px squares — clean, readable, no icon library dependency"
  - "render_social_card helper isolates card markup — view stays readable, subreddit conditional contained in one place"

patterns-established:
  - "Stimulus tab controller pattern: static targets=[btn,tab], static values={defaultTab}, data-tab-id on both targets"
  - "Rails.cache error state: fetch error key written by job on failure, cleared on success, checked in controller and rendered before empty state"
  - "content_tag + safe_join helper pattern for complex card markup in Rails helpers"

requirements-completed: [HN-01, HN-03, RDT-01, RDT-03, SOC-02, SOC-03]

# Metrics
duration: ~30min (across two sessions including checkpoint)
completed: 2026-02-24
---

# Phase 2 Plan 03: Social Feed UI Summary

**Stimulus-powered tabbed social feed on dashboard with HN and Reddit cards, platform badges, error/empty states, and HN discussion URL fallback**

## Performance

- **Duration:** ~30min (across two sessions including checkpoint verification)
- **Started:** 2026-02-24 (previous session)
- **Completed:** 2026-02-24T15:20:38Z
- **Tasks:** 3 (2 auto + 1 checkpoint verify)
- **Files modified:** 6

## Accomplishments

- Stimulus tabs controller built with data-tab-id matching strategy — HN, Reddit, and All tabs switch without page reload
- Social section added to dashboard below GitHub metrics with sorted post cards, platform badges, timestamps, error and empty states
- HN posts without an external URL fall back to hn_discussion_url — Ask HN posts always have a valid link (never a dead '#')
- Dashboard controller extended with social post queries, per-platform last_fetched_at timestamps, and Rails.cache fetch error reads
- 8 new controller tests covering social rendering, error state precedence, empty state, and sticky nav link
- User visually approved the section at checkpoint — dark theme, tab switching, colored badges confirmed

## Task Commits

Each task was committed atomically:

1. **Task 1: Create Stimulus tabs controller and extend DashboardController** - `ce7c847` (feat)
2. **Task 2: Build social section UI with cards, tabs, badges, error states, empty states, and CSS** - `f54c41d` (feat)
3. **Task 3: Visual verification** - checkpoint approved by user (no code commit)

## Files Created/Modified

- `app/javascript/controllers/tabs_controller.js` - Stimulus controller for tab switching; static targets=[btn,tab], static values={defaultTab}
- `app/controllers/dashboard_controller.rb` - Extended index action with @hn_posts, @reddit_posts, @all_posts, timestamps, and fetch error state from cache
- `app/helpers/dashboard_helper.rb` - render_social_card helper with HN discussion URL fallback and conditional subreddit display
- `app/views/dashboard/index.html.erb` - Social section with tabs, cards, error/empty states, sticky nav "Social" link
- `app/assets/stylesheets/application.css` - Dark-themed CSS for .dash-social-card, .dash-tab-nav, .dash-tab-btn, .dash-social-badge--hn/reddit, error/empty states
- `test/controllers/dashboard_controller_test.rb` - 8 new tests; Rails.cache MemoryStore swap pattern for error state tests

## Decisions Made

- **Stimulus tab matching via data-tab-id**: Both button and panel share the same `data-tab-id` attribute. The `select` method reads `event.currentTarget.dataset.tabId` and `showTab` hides/shows panels by comparing `t.dataset.tabId !== tabId`. No id attribute management needed.
- **Error state precedes empty state in ERB**: The view checks `@hn_fetch_error.present?` before `@hn_posts.empty?`. This is the locked user decision: a failed fetch shows "Unable to fetch HN posts" even when stale posts exist from a previous successful fetch.
- **Single-letter text badges**: Used "Y" (orange #ff6600) for HN and "R" (red #ff4500) for Reddit in 28×28px rounded squares. Clean, readable, no icon library dependency, consistent with dark theme.
- **render_social_card as helper method**: Isolated card markup in dashboard_helper.rb using content_tag + safe_join. Keeps ERB clean and keeps the HN fallback URL logic in one tested location.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None. All tasks completed cleanly. Rails.cache MemoryStore swap pattern (established in plan 02-02) was reused correctly in new controller tests.

## User Setup Required

**External services require manual configuration.**
Reddit OAuth2 app credentials are required before social jobs can authenticate in production:

- `REDDIT_CLIENT_ID` — from reddit.com/prefs/apps → create app → script type → client ID shown under app name
- `REDDIT_CLIENT_SECRET` — from reddit.com/prefs/apps → create app → script type → secret field
- Register at: https://www.reddit.com/prefs/apps → "create another app..." → select "script" → set redirect URI to http://localhost:8080

HN fetching has no credentials requirement and will work independently.

## Next Phase Readiness

- Phase 2 is now complete: SocialPost model, API clients, background jobs, and dashboard UI all delivered
- Social feed section is live on the dashboard and will populate once jobs are scheduled and credentials configured
- Phase 3 (YouTube Channel Metrics) can begin — no blockers from Phase 2
- Remaining concern: Reddit OAuth2 credentials must be configured before Phase 2 jobs run in production

## Self-Check: PASSED

- FOUND: app/javascript/controllers/tabs_controller.js
- FOUND: app/controllers/dashboard_controller.rb
- FOUND: app/helpers/dashboard_helper.rb
- FOUND: app/views/dashboard/index.html.erb
- FOUND: .planning/phases/02-social-feed-hn-and-reddit/02-03-SUMMARY.md
- FOUND commit: ce7c847 (Task 1)
- FOUND commit: f54c41d (Task 2)

---
*Phase: 02-social-feed-hn-and-reddit*
*Completed: 2026-02-24*
