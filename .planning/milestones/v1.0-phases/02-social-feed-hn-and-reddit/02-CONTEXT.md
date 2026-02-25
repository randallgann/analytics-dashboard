# Phase 2: Social Feed — HN and Reddit - Context

**Gathered:** 2026-02-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Display recent Hacker News and Reddit posts mentioning OpenClaw in a card-based social feed on the dashboard, updated every 2 hours. Each card shows a platform badge, metadata, and links. Feeds are independent — one platform failing does not affect the other. No commenting, bookmarking, or interaction features.

</domain>

<decisions>
## Implementation Decisions

### Card layout & content
- Medium cards: 2-3 lines per post with title, metadata row, and platform badge
- Metadata per card: score/points/upvotes, comment count, author, date, and subreddit (Reddit only)
- Platform badge: colored icon only (HN "Y" icon, Reddit alien icon in brand colors) — no text label
- Cards link to the original URL the post points to (not the discussion/comments page)

### Feed ordering & sections
- Tabbed view: single "Social" section with tabs to switch between HN, Reddit, or All
- Placed below the existing GitHub metrics sections on the dashboard
- Add "Social" to the sticky nav bar as a new section link
- Posts sorted by highest score first within each tab
- Show top 5 posts per tab — compact highlights view

### Empty & stale states
- Simple message when no mentions found: "No recent mentions found on Hacker News" (or Reddit) — plain text, subdued, consistent with GitHub chart empty states
- Subtle timestamp only for staleness: "Last updated X ago" in small muted text — no warning badges
- Failed platform tab stays visible with error message: "Unable to fetch [platform] posts" — user knows the feature exists but is temporarily unavailable

### Post matching criteria
- Name match only: search for "OpenClaw" in post titles and text — no URL matching or broad terms
- 30-day lookback window: consistent with GitHub metrics time range
- Case sensitivity: Claude's discretion based on what each platform's API supports

### Claude's Discretion
- Case sensitivity approach per platform API
- Which subreddits to search (all of Reddit vs curated list — based on API capabilities)
- Exact icon/badge design within the dark theme
- Tab implementation details (CSS tabs, JS tabs, etc.)
- "All" tab interleaving strategy

</decisions>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches. Dashboard should maintain the existing dark theme established in Phase 1.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 02-social-feed-hn-and-reddit*
*Context gathered: 2026-02-23*
