# Requirements: OpenClaw Analytics Dashboard

**Defined:** 2026-02-23
**Core Value:** Anyone can see at a glance how OpenClaw is growing and what people are saying about it

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Infrastructure

- [x] **INFRA-01**: SQLite WAL mode enabled on all databases to prevent write contention from concurrent background jobs
- [x] **INFRA-02**: Shared rate-limit-aware HTTP client module with exponential backoff and typed errors (RateLimitError, AuthError, NotFoundError)
- [x] **INFRA-03**: API credentials stored in Rails credentials or ENV variables, never hardcoded
- [x] **INFRA-04**: Solid Queue recurring job schedule configured for all data fetch jobs
- [x] **INFRA-05**: Data retention job prunes records older than 30 days daily

### GitHub Metrics

- [x] **GH-01**: Dashboard displays star count over time as a line chart (30-day rolling window)
- [x] **GH-02**: Dashboard displays fork count over time as a line chart (30-day rolling window)
- [x] **GH-03**: Dashboard displays open vs. closed issue counts
- [x] **GH-04**: Dashboard displays PR activity (open/merged/closed)
- [x] **GH-05**: Dashboard displays commit frequency (per day)
- [x] **GH-06**: Dashboard displays contributor count and new contributor growth
- [x] **GH-07**: Dashboard displays latest release info and release cadence
- [x] **GH-08**: Background job fetches GitHub metrics via Octokit every 6 hours
- [x] **GH-09**: GitHub data stored in GitHubMetric model (metric_type + value + recorded_on, unique index)

### Social Tracking — Hacker News

- [x] **HN-01**: Dashboard displays recent HN posts mentioning OpenClaw as card feed
- [x] **HN-02**: Each HN card shows title, points, comment count, author, and published date
- [x] **HN-03**: Each HN card links to original HN discussion
- [x] **HN-04**: Background job fetches HN posts via Algolia API every 2 hours

### Social Tracking — Reddit

- [x] **RDT-01**: Dashboard displays recent Reddit posts mentioning OpenClaw as card feed
- [x] **RDT-02**: Each Reddit card shows title, upvotes, comment count, subreddit, author, and published date
- [x] **RDT-03**: Each Reddit card links to original Reddit post
- [x] **RDT-04**: Background job fetches Reddit posts via API (OAuth2 if needed) every 2 hours

### Social Tracking — YouTube

- [ ] **YT-01**: Dashboard displays recent YouTube videos mentioning OpenClaw as card feed
- [ ] **YT-02**: Each YouTube card shows title, view count, channel name, and published date
- [x] **YT-03**: Each YouTube card links to original YouTube video
- [x] **YT-04**: Background job fetches YouTube videos via Data API v3 (max 4x/day to respect quota)

### Social Data Model

- [x] **SOC-01**: All social posts stored in normalized SocialPost model (platform + external_id + title + url + author + score + comment_count + published_at)
- [x] **SOC-02**: Platform badge displayed on each social card (HN, Reddit, YouTube)
- [x] **SOC-03**: "Last updated" timestamp shown per data source section

### Dashboard Presentation

- [ ] **DASH-01**: Hero metrics row showing total stars, forks, open issues with 7-day delta indicators
- [x] **DASH-02**: Time-series charts rendered via Chartkick/Chart.js with real data (replacing static placeholders)
- [ ] **DASH-03**: Social posts ranked by recency-weighted engagement score (fresh + engaging posts surface first)
- [ ] **DASH-04**: OpenGraph meta tags for rich preview when dashboard URL is shared
- [x] **DASH-05**: Page loads under 3 seconds (all data pre-fetched by background jobs)
- [x] **DASH-06**: Public-facing, no authentication required

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### X/Twitter Integration

- **TW-01**: Dashboard displays recent X/Twitter posts mentioning OpenClaw
- **TW-02**: Background job fetches X/Twitter posts via API v2

### Advanced Features

- **ADV-01**: Cross-platform correlation view (star spikes alongside mention spikes)
- **ADV-02**: Custom date range picker beyond 30-day window
- **ADV-03**: Responsive mobile-optimized layout
- **ADV-04**: Email/webhook notifications for viral moments

## Out of Scope

| Feature | Reason |
|---------|--------|
| X/Twitter for v1 | API requires $100/month minimum for search; design around its absence |
| Real-time WebSocket updates | Background jobs on schedule sufficient; OSS metrics don't change second-to-second |
| User accounts / authentication | Public dashboard only; gates audience |
| Sentiment analysis | NLP dependency; unreliable on technical content |
| Multi-repo comparison | Single-repo focus; doubles complexity |
| Historical data beyond 30 days | Unbounded SQLite growth; API history access restricted |
| Mobile app | Responsive web sufficient for audience |
| Export to CSV/PDF | Low value relative to cost; display-only dashboard |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| INFRA-01 | Phase 1 | Complete |
| INFRA-02 | Phase 1 | Complete |
| INFRA-03 | Phase 1 | Complete |
| INFRA-04 | Phase 1 | Complete |
| INFRA-05 | Phase 1 | Complete |
| GH-01 | Phase 1 | Complete |
| GH-02 | Phase 1 | Complete |
| GH-03 | Phase 1 | Complete |
| GH-04 | Phase 1 | Complete |
| GH-05 | Phase 1 | Complete |
| GH-06 | Phase 1 | Complete |
| GH-07 | Phase 1 | Complete |
| GH-08 | Phase 1 | Complete |
| GH-09 | Phase 1 | Complete |
| HN-01 | Phase 2 | Complete |
| HN-02 | Phase 2 | Complete |
| HN-03 | Phase 2 | Complete |
| HN-04 | Phase 2 | Complete |
| RDT-01 | Phase 2 | Complete |
| RDT-02 | Phase 2 | Complete |
| RDT-03 | Phase 2 | Complete |
| RDT-04 | Phase 2 | Complete |
| SOC-01 | Phase 2 | Complete |
| SOC-02 | Phase 2 | Complete |
| SOC-03 | Phase 2 | Complete |
| YT-01 | Phase 3 | Pending (UI — Plan 02) |
| YT-02 | Phase 3 | Pending (UI — Plan 02) |
| YT-03 | Phase 3 | Complete (03-01) |
| YT-04 | Phase 3 | Complete (03-01) |
| DASH-01 | Phase 4 | Pending |
| DASH-02 | Phase 1 | Complete |
| DASH-03 | Phase 4 | Pending |
| DASH-04 | Phase 4 | Pending |
| DASH-05 | Phase 1 | Complete |
| DASH-06 | Phase 1 | Complete |

**Coverage:**
- v1 requirements: 35 total
- Mapped to phases: 35
- Unmapped: 0 ✓

---
*Requirements defined: 2026-02-23*
*Last updated: 2026-02-23 after initial definition*
