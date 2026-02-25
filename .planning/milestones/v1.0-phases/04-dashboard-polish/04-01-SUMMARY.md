---
phase: 04-dashboard-polish
plan: 01
subsystem: ui
tags: [rails, activerecord, time-decay, hero-metrics, css-grid, dashboard]

# Dependency graph
requires:
  - phase: 03-youtube-integration
    provides: YouTube social posts in SocialPost model (score stores view count, platform youtube)
  - phase: 02-social-feed-hn-and-reddit
    provides: SocialPost model with score/comment_count/published_at; last_30_days scope
  - phase: 01-foundation-github-pipeline
    provides: GitHubMetric model with recorded_on date column and for_metric/latest_value scopes
provides:
  - GitHubMetric.delta_value: 7-day signed delta for any metric type (nil when <7 days data)
  - SocialPost.ranked_by_engagement: HN-style time-decay sorted Array (not Relation)
  - DashboardHelper.render_hero_metric and format_delta: nil-safe hero card rendering
  - Hero metrics row at top of dashboard showing stars/forks/open_issues with delta indicators
  - Engagement-ranked social feed per platform; All tab uses recency order
affects: [04-dashboard-polish]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - HN-style time-decay formula (engagement / (age_hours + 2)^1.8) for social ranking
    - Single-fetch + Ruby partition pattern for social feed (avoids N+1 DB queries)
    - Nil-safe delta rendering with "No baseline yet" fallback for new deployments
    - Boundless range query (recorded_on: ...(Date.today - days)) for 7-day baseline lookup

key-files:
  created: []
  modified:
    - app/models/github_metric.rb
    - app/models/social_post.rb
    - app/helpers/dashboard_helper.rb
    - app/controllers/dashboard_controller.rb
    - app/views/dashboard/index.html.erb
    - app/assets/stylesheets/application.css
    - test/models/github_metric_test.rb
    - test/models/social_post_test.rb
    - test/controllers/dashboard_controller_test.rb
    - test/fixtures/social_posts.yml

key-decisions:
  - "DASH-03 All tab uses recency order (published_at DESC) not engagement ranking — avoids YouTube view count domination (scores are 10-100x larger than HN/Reddit points)"
  - "ranked_by_engagement returns plain Array (sort_by result) — callers must partition in Ruby, cannot chain .where"
  - "Single-fetch pattern: controller calls ranked_by_engagement(limit: 50) once, partitions in Ruby with select(&:hn?) etc — avoids 4 redundant DB queries"
  - "Fixture dates updated from 2025-12 to 2026-02 — last_30_days scope excluded old fixture posts from ranked/all feeds, breaking existing HN/Reddit title assertions"

patterns-established:
  - "Hero card pattern: render_hero_metric helper renders label/value/delta as content_tag chain with safe_join"
  - "Delta color coding: dash-delta--positive (green #34d399), dash-delta--negative (red #f87171), dash-delta--neutral (muted #475569)"
  - "Mobile-first hero row: 3-column grid collapses to 1-column at max-width 640px"

requirements-completed: [DASH-01, DASH-03]

# Metrics
duration: 3min
completed: 2026-02-25
---

# Phase 4 Plan 01: Dashboard Polish — Hero Metrics + Engagement Ranking Summary

**Hero metrics row with 7-day delta indicators and HN-style time-decay engagement ranking replacing raw score sort for social feed tabs**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-25T02:51:20Z
- **Completed:** 2026-02-25T02:54:39Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments
- Added `GitHubMetric.delta_value` — returns signed 7-day delta (nil-safe for new deployments)
- Added `SocialPost.ranked_by_engagement` — HN-style time-decay sort (GRAVITY=1.8, comment_count*2 weights discussion)
- Added `render_hero_metric` and `format_delta` helpers to DashboardHelper
- Wired hero metrics row at top of dashboard (inside `@has_data` block) showing stars, forks, open issues with color-coded deltas
- Replaced raw `top_posts` scope with single-fetch engagement ranking; All tab uses recency order to prevent YouTube domination

## Task Commits

Each task was committed atomically:

1. **Task 1: Add delta_value, ranked_by_engagement, and hero helpers** - `4c829c9` (feat)
2. **Task 2: Wire hero row and engagement ranking into dashboard** - `1823727` (feat)

**Plan metadata:** (docs commit — see state updates below)

## Files Created/Modified
- `app/models/github_metric.rb` - Added `delta_value` class method with boundless range query
- `app/models/social_post.rb` - Added `GRAVITY` constant and `ranked_by_engagement` class method
- `app/helpers/dashboard_helper.rb` - Added `render_hero_metric` and `format_delta` helpers
- `app/controllers/dashboard_controller.rb` - Added delta instance vars; replaced top_posts with single-fetch pattern; added All tab recency query
- `app/views/dashboard/index.html.erb` - Added hero metrics row section above Stars & Forks
- `app/assets/stylesheets/application.css` - Added dash-hero-row, dash-hero-card, dash-hero-label, dash-hero-value, dash-delta modifier classes
- `test/models/github_metric_test.rb` - 3 delta_value tests (normal, <7 days, no data)
- `test/models/social_post_test.rb` - 3 ranked_by_engagement tests (decay sort, nil exclusion, empty)
- `test/controllers/dashboard_controller_test.rb` - 3 hero row + engagement tests
- `test/fixtures/social_posts.yml` - Updated dates from 2025-12 to 2026-02 (see Deviations)

## Decisions Made
- All tab uses `published_at DESC` (recency only), not engagement ranking — prevents YouTube view counts (14k+) from dominating HN/Reddit scores (75-150 range)
- `ranked_by_engagement` returns Array, documented on method — callers must use Ruby select/partition
- Single-fetch pattern: fetch `limit: 50` once, partition in Ruby — matches RESEARCH Pitfall 5 recommendation

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated fixture dates to keep posts within last_30_days scope**
- **Found during:** Task 2 (controller test run — full test suite)
- **Issue:** Fixture `published_at` dates were 2025-12-15 through 2025-12-17 (70+ days ago). The new `ranked_by_engagement` uses `last_30_days` scope, excluding them. Existing tests asserting HN/Reddit post titles appear in response body failed.
- **Fix:** Updated `test/fixtures/social_posts.yml` to use 2026-02-20 through 2026-02-22 dates, within 30 days of current date
- **Files modified:** `test/fixtures/social_posts.yml`
- **Verification:** All 94 tests pass after update
- **Committed in:** `1823727` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 — bug)
**Impact on plan:** Required for correctness — old fixture dates conflicted with new scope behavior. No scope creep.

## Issues Encountered
- System Ruby (2.6) picked up by `bin/rails` shebang instead of project Ruby (3.3.6). Resolved by invoking tests as `/Users/rgann/.rubies/ruby-3.3.6/bin/ruby bin/rails test` — consistent with how previous phases ran tests in this project.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- DASH-01 and DASH-03 complete; ready for DASH-04 (OpenGraph meta tags) in plan 04-02
- Hero row renders with "No baseline yet" on fresh deployments — nil guard working correctly
- Engagement ranking formula tunable via `SocialPost::GRAVITY` constant if needed

---
*Phase: 04-dashboard-polish*
*Completed: 2026-02-25*
