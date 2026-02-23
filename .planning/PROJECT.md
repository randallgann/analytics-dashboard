# OpenClaw Analytics Dashboard

## What This Is

A public-facing analytics dashboard that tracks the popularity and social buzz around the OpenClaw open-source project. It pulls GitHub repository metrics (stars, forks, issues, PRs, commits, contributors) and surfaces trending social media posts from X/Twitter, Reddit, Hacker News, and YouTube — all powered by scheduled background jobs with a 30-day rolling window.

## Core Value

Anyone can see at a glance how OpenClaw is growing and what people are saying about it — GitHub traction and social buzz in one place.

## Requirements

### Validated

<!-- Inferred from existing codebase -->

- ✓ Rails 8.1 MVC application with Hotwire (Turbo + Stimulus) — existing
- ✓ Chart.js/Chartkick data visualization — existing
- ✓ Solid Queue background job infrastructure — existing
- ✓ SQLite3 multi-database setup (primary, cache, queue, cable) — existing
- ✓ Docker/Kamal deployment pipeline — existing
- ✓ Propshaft asset pipeline with import maps — existing

### Active

<!-- New requirements for OpenClaw tracking -->

- [ ] GitHub metrics: stars & forks over time (30-day rolling)
- [ ] GitHub metrics: issues & PRs activity (open/closed, velocity)
- [ ] GitHub metrics: release & commit activity (frequency, cadence)
- [ ] GitHub metrics: contributor growth (new contributors, top contributors)
- [ ] Social tracking: X/Twitter posts about OpenClaw ranked by recency + engagement
- [ ] Social tracking: Reddit posts and discussions mentioning OpenClaw
- [ ] Social tracking: Hacker News posts and comments about OpenClaw
- [ ] Social tracking: YouTube videos mentioning OpenClaw
- [ ] Scheduled background jobs to fetch and store all data sources
- [ ] Time-series charts for GitHub metrics
- [ ] Card-based feeds for trending social posts
- [ ] Public-facing dashboard (no authentication required)

### Out of Scope

- Real-time streaming / WebSocket updates — background jobs are sufficient for v1
- User accounts or authentication — public dashboard only
- Custom date range selection — fixed 30-day window for v1
- Mobile app — web-only, responsive design sufficient
- Polished design — functional display is the v1 goal, styling later
- Notifications or alerts — display-only for v1

## Context

- **Existing codebase:** Rails 8.1 analytics dashboard with Chartkick/Chart.js already wired up, Solid Queue for background jobs, Docker/Kamal deployment. The foundation is solid but currently shows placeholder/static data.
- **OpenClaw:** A recently created and very popular open-source git repository. The dashboard will track its growth trajectory across GitHub and social media.
- **API keys needed:** GitHub personal access token, X/Twitter API credentials, Reddit API app credentials. User will set these up during implementation. Hacker News and YouTube may have free/unauthenticated endpoints.
- **Data retention:** 30-day rolling window to keep storage manageable on SQLite.
- **Trending definition:** Recent posts sorted by engagement — freshness matters more than all-time totals.

## Constraints

- **Database**: SQLite3 — already configured, must work within its concurrency limits
- **API Rate Limits**: GitHub API (5,000 req/hr authenticated), X/Twitter (varies by tier), Reddit (100 req/min) — background jobs must respect these
- **No API keys yet**: Implementation must be structured so API integrations can be configured via environment variables or Rails credentials
- **Storage**: 30-day rolling window to prevent unbounded SQLite growth
- **Tech stack**: Must build on existing Rails 8.1 / Hotwire / Chartkick stack — no SPA framework

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scheduled background jobs over live API calls | Faster page loads, respect rate limits, store historical data | — Pending |
| 30-day rolling window | Keep SQLite storage bounded, focus on recent trends | — Pending |
| Recency + engagement for trending | Fresh content matters more than all-time popularity | — Pending |
| Charts for GitHub, cards for social | Match data type to best visualization format | — Pending |
| Public-facing, no auth | Maximize visibility, simplify v1 | — Pending |

---
*Last updated: 2026-02-23 after initialization*
