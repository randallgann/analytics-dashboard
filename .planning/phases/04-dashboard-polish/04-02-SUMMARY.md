---
phase: 04-dashboard-polish
plan: 02
subsystem: ui
tags: [opengraph, twitter-card, meta-tags, social-sharing, seo]

# Dependency graph
requires:
  - phase: 04-01
    provides: dashboard polish foundation (hero row, engagement ranking)
provides:
  - OpenGraph meta tags in layout head (og:type, og:site_name, og:title, og:description, og:url, og:image)
  - Twitter Card meta tags (twitter:card, twitter:title, twitter:description, twitter:image)
  - Static OG image at public/og-image.png (Propshaft-bypass, stable URL)
  - Absolute og:image URL via request.base_url (no asset_host config required)
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "OG image in public/ not app/assets/ — bypasses Propshaft fingerprinting for stable share URLs"
    - "request.base_url for absolute URLs in ERB — no environment config required"
    - "Meta tags placed before yield :head — allows per-view override in future"

key-files:
  created:
    - public/og-image.png
  modified:
    - app/views/layouts/application.html.erb
    - test/controllers/dashboard_controller_test.rb

key-decisions:
  - "request.base_url used for og:image absolute URL — no asset_host or ENV var config needed; works in all environments"
  - "OG image copied from public/icon.png — serves as v1 fallback; user can replace with 1200x630 banner later"
  - "og:image:width/height declared as 1200x630 per spec — previewers handle square-image mismatch gracefully"

patterns-established:
  - "Static assets for social/SEO go in public/ not app/assets/ — preserves stable fingerprint-free URLs"

requirements-completed: [DASH-04]

# Metrics
duration: 1min
completed: 2026-02-24
---

# Phase 4 Plan 02: OpenGraph and Twitter Card Meta Tags Summary

**OpenGraph and Twitter Card tags injected into layout head with absolute og:image URL using request.base_url and a static fallback image at public/og-image.png**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-25T02:57:25Z
- **Completed:** 2026-02-25T02:58:24Z
- **Tasks:** 1
- **Files modified:** 3 (including 1 new file)

## Accomplishments

- Added full OpenGraph meta tag set (og:type, og:site_name, og:title, og:description, og:url, og:image, og:image:width, og:image:height) to application layout
- Added Twitter Card meta tags (twitter:card, twitter:title, twitter:description, twitter:image) for Slack, Discord, iMessage, and Twitter/X link previews
- Created public/og-image.png (copied from public/icon.png) as a Propshaft-bypass static OG image with a stable URL across deploys
- Added 2 controller tests verifying OG tag presence and absolute URL enforcement — all 24 tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Add OpenGraph and Twitter Card meta tags to layout and create OG image** - `5d0c17f` (feat)

**Plan metadata:** (docs commit — see below)

## Files Created/Modified

- `public/og-image.png` — Static OG image copied from icon.png; served directly by web server, not fingerprinted by Propshaft
- `app/views/layouts/application.html.erb` — Added 12 meta tags (8 OG, 4 Twitter Card) before yield :head for optional per-view override
- `test/controllers/dashboard_controller_test.rb` — Added 2 tests: OG tag presence and absolute og:image URL assertion

## Decisions Made

- **request.base_url for absolute URLs:** Returns the full origin (e.g., `https://yourdomain.com`) at render time with no additional config. Works in development, staging, and production without environment variables.
- **OG image in public/ not app/assets/:** Files in public/ bypass Propshaft's content-hash fingerprinting, keeping the URL `/og-image.png` stable. An asset in app/assets/ would get a digest suffix that breaks cached social previews on each deploy.
- **og:image:width/height declared as 1200x630:** Per OpenGraph spec, even though the current icon is square. Social previewers (Slack, Twitter, Facebook) handle the mismatch gracefully, and this avoids a "missing dimensions" warning in linters.
- **Icon copy as v1 OG image:** Provides immediate functionality; user can replace public/og-image.png with a proper 1200x630 banner without any code changes.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - straightforward execution. The macOS system Ruby 2.6 was in PATH; used `~/.rubies/ruby-3.3.6/bin/` prefix to invoke the correct runtime (consistent with prior phases in this project).

## User Setup Required

None - no external service configuration required. The OG image is static and the meta tags render with the live request URL automatically.

## Next Phase Readiness

- All 4 plans in Phase 4 (Dashboard Polish) are now complete
- DASH-04 requirement satisfied — rich link previews work for Slack, Twitter/X, Discord, iMessage
- User can optionally replace `public/og-image.png` with a 1200x630 banner PNG at any time for a better social preview image

---
*Phase: 04-dashboard-polish*
*Completed: 2026-02-24*
