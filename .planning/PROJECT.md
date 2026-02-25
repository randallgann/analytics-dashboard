# OpenClaw Analytics Dashboard

## What This Is

A public-facing analytics dashboard that tracks the popularity and social buzz around the OpenClaw open-source project. It pulls GitHub repository metrics (stars, forks, issues, PRs, commits, contributors, releases) and surfaces trending social media posts from Hacker News, Reddit, and YouTube — all powered by scheduled background jobs with a 30-day rolling window, displayed in a dark-themed single-page dashboard with hero metrics, time-series charts, and a ranked social feed.

## Core Value

Anyone can see at a glance how OpenClaw is growing and what people are saying about it — GitHub traction and social buzz in one place.

## Requirements

### Validated

- ✓ Rails 8.1 MVC application with Hotwire (Turbo + Stimulus) — existing
- ✓ Chart.js/Chartkick data visualization — existing
- ✓ Solid Queue background job infrastructure — existing
- ✓ SQLite3 multi-database setup (primary, cache, queue, cable) — existing
- ✓ Docker/Kamal deployment pipeline — existing
- ✓ Propshaft asset pipeline with import maps — existing
- ✓ GitHub metrics: stars & forks over time (30-day rolling) — v1.0
- ✓ GitHub metrics: issues & PRs activity (open/closed) — v1.0
- ✓ GitHub metrics: release & commit activity (frequency, cadence) — v1.0
- ✓ GitHub metrics: contributor growth — v1.0
- ✓ Social tracking: Hacker News posts mentioning OpenClaw — v1.0
- ✓ Social tracking: Reddit posts and discussions mentioning OpenClaw — v1.0
- ✓ Social tracking: YouTube videos mentioning OpenClaw — v1.0
- ✓ Scheduled background jobs to fetch and store all data sources — v1.0
- ✓ Time-series charts for GitHub metrics — v1.0
- ✓ Card-based feeds for trending social posts — v1.0
- ✓ Public-facing dashboard (no authentication required) — v1.0
- ✓ Hero metrics row with 7-day delta indicators — v1.0
- ✓ Recency-weighted engagement ranking for social feed — v1.0
- ✓ OpenGraph meta tags for rich link previews — v1.0

### Active

(None — define with `/gsd:new-milestone`)

### Out of Scope

- X/Twitter integration — API requires $100/month minimum for search; deferred to v2 pending cost approval
- Real-time streaming / WebSocket updates — background jobs are sufficient; OSS metrics don't change second-to-second
- User accounts or authentication — public dashboard only; gates audience
- Custom date range selection — fixed 30-day window; unbounded SQLite growth
- Mobile app — responsive web sufficient for audience
- Notifications or alerts — display-only dashboard
- Sentiment analysis — NLP dependency; unreliable on technical content
- Multi-repo comparison — single-repo focus; doubles complexity
- Export to CSV/PDF — low value relative to cost; display-only dashboard

## Context

- **Shipped v1.0** with ~2,995 LOC Ruby across 72 files in 2 days
- **Tech stack:** Rails 8.1, Hotwire (Turbo + Stimulus), Chartkick/Chart.js, SQLite3 (WAL mode), Solid Queue, Propshaft, Docker/Kamal
- **Data pipelines:** 5 background jobs — GithubMetricJob (6h), HnSocialJob (2h), RedditSocialJob (2h), YoutubeSocialJob (6h), DataRetentionJob (daily)
- **API integrations:** GitHub (Octokit), HN (Algolia), Reddit (public JSON), YouTube (Data API v3)
- **API keys needed:** GitHub PAT (configured), YouTube API key (configured), Reddit (public endpoint, no creds needed)
- **Test suite:** ~90+ tests, 0 failures
- **Known tech debt:** 6 minor items (dead code, implicit WAL config, view-model coupling) — see MILESTONES.md

## Constraints

- **Database**: SQLite3 — must work within its concurrency limits (WAL mode enabled via gem default)
- **API Rate Limits**: GitHub API (5,000 req/hr authenticated), Reddit (public endpoint), YouTube (10,000 units/day free tier, ~400 units/day used)
- **Storage**: 30-day rolling window to prevent unbounded SQLite growth
- **Tech stack**: Must build on existing Rails 8.1 / Hotwire / Chartkick stack — no SPA framework

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Scheduled background jobs over live API calls | Faster page loads, respect rate limits, store historical data | ✓ Good — 17 DB queries, 0 API calls in request path |
| 30-day rolling window | Keep SQLite storage bounded, focus on recent trends | ✓ Good — DataRetentionJob prunes daily |
| Recency + engagement for trending | Fresh content matters more than all-time popularity | ✓ Good — HN-style time-decay formula with GRAVITY=1.8 |
| Charts for GitHub, cards for social | Match data type to best visualization format | ✓ Good — Chartkick charts + render_social_card helper |
| Public-facing, no auth | Maximize visibility, simplify v1 | ✓ Good — no ApplicationController auth |
| X/Twitter deferred to v2 | $100/month minimum API cost | ✓ Good — focused budget on free APIs first |
| Reddit public JSON instead of OAuth2 | Simpler, no credentials needed | ✓ Good — works reliably with no auth config |
| All tab uses recency not engagement | YouTube view counts (10k-1M) dwarf HN/Reddit points (10-5k) | ✓ Good — prevents YouTube domination |
| OG image in public/ not assets/ | Stable URL across deploys (no Propshaft fingerprinting) | ✓ Good — social crawlers always find the image |
| Single-fetch + Ruby partition pattern | One ranked_by_engagement(50) call, partition in Ruby | ✓ Good — avoids N+1, returns Array not Relation |

---
*Last updated: 2026-02-25 after v1.0 milestone*
