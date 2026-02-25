---
phase: 03-youtube-integration
plan: 02
subsystem: ui
tags: [youtube, dashboard, stimulus, tabs, social-cards, rails-views]

# Dependency graph
requires:
  - phase: 03-youtube-integration/03-01
    provides: YoutubeClient, YoutubeSocialJob, "youtube" SocialPost platform, youtube? predicate, channel_name in author column, social_fetch_error:youtube cache key
  - phase: 02-social-feed-hn-and-reddit/02-03
    provides: render_social_card helper, Stimulus tabs controller, dash-social-badge CSS pattern, HN/Reddit tab structure to mirror

provides:
  - YouTube tab button in dashboard social section (alongside HN, Reddit, All)
  - YouTube video cards with red "YT" badge, view count display, channel name, published date
  - YouTube empty state: "No recent mentions found on YouTube"
  - YouTube error state: "Unable to fetch YouTube videos"
  - YouTube posts included in All tab sorted by score
  - dash-social-badge--youtube CSS (YouTube brand red #ff0000)

affects: [04-deployment, dashboard-ui, social-feed]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Three-way badge conditional: hn? -> Y, reddit? -> R, else -> YT (extends single-letter badge pattern)"
    - "youtube? guard on comments meta part — YouTube comment_count is always 0, skip rendering entirely"
    - "Controller error state + empty state + post list triple conditional, error check precedes empty check"

key-files:
  created: []
  modified:
    - app/controllers/dashboard_controller.rb
    - app/helpers/dashboard_helper.rb
    - app/views/dashboard/index.html.erb
    - app/assets/stylesheets/application.css
    - test/controllers/dashboard_controller_test.rb

key-decisions:
  - "YT badge text distinguishes from HN Y badge — two chars vs one, both inside brand-colored 28x28 square"
  - "View count shown instead of pts for YouTube — score column stores view count but label must match platform semantics"
  - "Comments meta part skipped for YouTube — comment_count always 0 from API, renders useless '0 comments' without the guard"
  - "Error state check precedes empty check in YouTube tab panel — locked decision inherited from Phase 2 (02-03)"

patterns-established:
  - "Platform-conditional meta rendering: add youtube? branch to score label and suppress comment_count — pattern for any future zero-comment platform"
  - "Tab panel structure: last-updated timestamp, error state, empty state, post list — same order for all three platforms"

requirements-completed: [YT-01, YT-02, YT-03]

# Metrics
duration: 15min
completed: 2026-02-24
---

# Phase 3 Plan 02: YouTube Dashboard UI Summary

**YouTube tab with video cards (red YT badge, view count, channel name) wired into the Stimulus tabs dashboard alongside HN and Reddit**

## Performance

- **Duration:** ~15 min
- **Started:** 2026-02-24T23:28:50Z (estimate)
- **Completed:** 2026-02-24 (checkpoint approved by user)
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 5

## Accomplishments

- DashboardController extended with `@youtube_posts`, `@youtube_last_updated`, and `@youtube_fetch_error` queries alongside existing HN/Reddit
- `render_social_card` helper extended with three-way badge (Y/R/YT), view count label for YouTube posts, and suppressed comment count (YouTube always returns 0)
- YouTube tab panel added to `dashboard/index.html.erb` with error, empty, and card states mirroring HN/Reddit structure exactly
- YouTube brand red badge (`.dash-social-badge--youtube`, `#ff0000`) added to application.css
- 5 new controller tests added covering: title display, tab button rendering, empty state, fetch error state, badge class rendering
- User confirmed visual verification: YouTube tab visible, empty state "No recent mentions found on YouTube" displays correctly

## Task Commits

Each task was committed atomically:

1. **Task 1: Dashboard controller, helper, view, CSS for YouTube tab** - `6947d22` (feat)
2. **Task 2: Visual verification checkpoint** - N/A (human-verify, no code commit)

**Plan metadata:** (docs commit — created after this summary)

## Files Created/Modified

- `app/controllers/dashboard_controller.rb` - Added @youtube_posts (top 5), @youtube_last_updated, @youtube_fetch_error queries
- `app/helpers/dashboard_helper.rb` - Three-way badge, view count for YouTube, suppressed comment count for YouTube
- `app/views/dashboard/index.html.erb` - YouTube tab button (before All) and YouTube tab panel with error/empty/card states
- `app/assets/stylesheets/application.css` - `.dash-social-badge--youtube { background: #ff0000; color: #fff; }`
- `test/controllers/dashboard_controller_test.rb` - 5 new YouTube UI tests (title, tab button, empty state, error state, badge class)

## Decisions Made

- **"YT" not "Y" for badge text:** HN already uses "Y" — YouTube needs two chars to distinguish. Stays within the 28x28px square badge defined by the base `.dash-social-badge` class.
- **View count label instead of "pts":** The `score` column stores view_count for YouTube posts (set by YoutubeClient). Rendering "X pts" would be semantically wrong; "X views" matches platform conventions.
- **Suppress comment count for YouTube:** The YouTube Data API returns comment_count but it is always 0 in practice for search results. Rendering "0 comments" on every card is noise; the `unless post.youtube?` guard removes it cleanly.
- **Error state precedes empty state:** Inherited locked decision from Phase 2 Plan 03 — if a fetch error exists, show the error even when stale posts remain in the database.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None — all 5 new tests passed on first run. User confirmed visual verification with empty state displaying correctly (expected in development since no YouTube job has run with a real API key yet).

## User Setup Required

None new — YouTube API key requirement was documented in 03-01-SUMMARY.md. The empty state confirmed in visual verification is expected behavior until `YOUTUBE_API_KEY` is configured and `YoutubeSocialJob` runs in production.

## Next Phase Readiness

- Phase 3 (YouTube Integration) is fully complete — data pipeline (Plan 01) and dashboard UI (Plan 02) both done
- YouTube posts appear in Social feed alongside HN and Reddit; All tab includes YouTube by default
- Phase 4 (Deployment) can proceed — all three social platforms are wired end-to-end

---
*Phase: 03-youtube-integration*
*Completed: 2026-02-24*
