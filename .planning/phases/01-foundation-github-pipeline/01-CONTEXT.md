# Phase 1: Foundation + GitHub Pipeline - Context

**Gathered:** 2026-02-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Set up shared infrastructure (SQLite WAL, HTTP client, credentials, job scheduling, data retention) and build a complete GitHub metrics pipeline — from API fetching to time-series charts showing real star, fork, issue, PR, commit, contributor, and release data. Social feeds and dashboard polish are separate phases.

</domain>

<decisions>
## Implementation Decisions

### Chart types & layout
- Claude's discretion on chart type per metric (line vs area vs bar) — pick what communicates best
- Charts arranged in a 2-column grid
- Claude's discretion on chart type for non-time-series metrics (issues open/closed, PR states, etc.)
- Hover tooltips on charts to show exact values, but no zoom/pan/interactive features

### Metric visual hierarchy
- Top tier (most prominent): stars, forks, and commit frequency
- Secondary tier: issues, PRs, contributors, releases
- Every chart/metric card gets a headline summary number above it (e.g., "1,247 stars")
- Latest release displayed as a single card (name, date, link) — not a chart
- Claude's discretion on contributor count display (big number + trend vs chart)

### Dashboard page structure
- Single scrolling page with sections and anchor links
- Sticky top nav bar with section names as clickable jump links
- Minimal header — just "OpenClaw" and "Analytics Dashboard" subtitle
- Dark theme — dark backgrounds with vibrant chart colors, modern developer dashboard feel

### Empty & loading states
- First deploy with no data: each chart area shows "Collecting data..." with estimated time until first data
- Partial data (less than 30 days): render whatever data exists, x-axis adapts to available range
- API errors: each affected chart shows its own error indicator, unaffected charts display normally
- Per-section "last updated" timestamps showing when each metric was last refreshed

### Claude's Discretion
- Specific chart type per metric (line, area, bar, donut, sparkline, etc.)
- Chart colors, spacing, typography within dark theme
- Contributor count display format
- Loading skeleton/animation design
- Error indicator design
- Exact section groupings for the nav

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-github-pipeline*
*Context gathered: 2026-02-23*
