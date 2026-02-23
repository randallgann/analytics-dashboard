# Features Research

**Domain:** GitHub repository analytics + multi-platform social media tracking
**Researched:** 2026-02-23
**Overall confidence:** MEDIUM (training data through ~August 2025; no live web access)

---

## Table Stakes — GitHub Metrics

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Star count over time (line chart) | Primary traction signal; every OSS tool shows it (OSS Insight, Star History, GitHub Insights) | Low | 30-day window + cumulative total + daily delta |
| Fork count over time | Developer adoption signal; always shown alongside stars | Low | Same chart shape as stars; can share component |
| Open vs. closed issue counts | Project health signal; missing = dashboard feels broken | Low-Med | Open count + trend minimum; close rate is bonus |
| PR activity (open/merged/closed) | Contribution velocity; "is this project active?" | Low-Med | Total open + recent merge rate |
| Commit frequency (per day/week) | Raw activity proxy; silence periods immediately visible | Med | GitHub commits API, aggregate by day |
| Contributor count | Community size; new contributors = project growing | Med | Unique contributors, period delta |
| Latest release / cadence | "Is there a stable version?"; "how often do they ship?" | Low | Latest tag + release date; frequency histogram optional |
| Scheduled background data refresh | Without this, data is stale; defeats the dashboard's purpose | Med | Already planned via Solid Queue |

## Table Stakes — Social Tracking

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Recent posts by platform (Twitter/X, Reddit, HN, YouTube) | Core value prop — what people say NOW, not aggregates | Med | Card-based feed per platform |
| Post engagement metrics (upvotes, likes, comments, views) | Distinguishes signal from noise; a post with 0 engagement is not "trending" | Low | Normalize to simple score across platforms |
| Link to original post | Without this, dashboard is a dead end; click-through is cardinal rule | Low | Required on every social card |
| Chronological + engagement sorting | "Latest" and "top" are the two modes every social aggregator offers | Low-Med | Default: recency-weighted engagement (per PROJECT.md) |
| Platform badge on each card | When mixing sources, origin must be instantly clear | Low | Platform logo/badge |
| Time window label | "Recent" means something; users need to know the horizon | Low | "Last 30 days" label in UI |

## Table Stakes — General Dashboard

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Hero/summary metrics row | Every analytics dashboard opens with top-line numbers; users orient here first | Low | Stars, forks, mentions with delta indicators |
| Time-series charts for GitHub metrics | Charts are expected for over-time data; static numbers alone are insufficient | Low-Med | Chartkick/Chart.js already in place |
| Responsive layout | Public dashboards get shared on social; people click links from phones | Low-Med | CSS/layout work, no new backend |
| Page load under 3 seconds | Slow analytics undermines trust in the data | Low | Background jobs pre-fetch; should be fast |
| "Last updated" timestamp per section | Users need to know data freshness; stale data that looks current is worse than no data | Low | Stored timestamp per fetch, rendered in UI |

---

## Differentiators

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Cross-platform social aggregation | No single platform shows all OSS discussion venues; aggregation IS the unique value | High | Different API auth, rate limits, data shapes per platform |
| Recency-weighted engagement ranking | Blended "trending" score (fresh + engaging) vs. pure chronological or pure popularity | Med | Score = engagement / age_hours^decay_factor |
| GitHub + social signal correlation | Star spike events alongside mention spikes reveals "what drove growth" — GitHub Insights can't answer this | High | Time-aligned display of both data types; complex but compelling |
| Hacker News tracking (separate from Reddit) | HN front page is a major OSS event; most dashboards skip it; Algolia API is free/unauthenticated | Med | Lowest integration friction of all platforms |
| YouTube video tracking | Tutorial videos drive real adoption; often precede star spikes; rarely done in OSS dashboards | High | YouTube Data API v3; 10K unit/day quota on free tier |
| Delta indicators on all metrics | "+142 stars today" beats "4,821 total stars"; change vs. baseline is more compelling than raw counts | Low-Med | Requires storing previous-period snapshots |
| OpenGraph embed for sharing | Rich preview when shared on Twitter/LinkedIn; dashboard becomes part of the social presence | Low | Rails meta tags or manual og: tags in layout |

---

## Anti-Features (Deliberately NOT Build)

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Real-time WebSocket updates | Complexity vs. value ratio is poor; OSS metrics don't change second-to-second | Background jobs on schedule (15-60 min) |
| User authentication / accounts | Gates the audience; defeats public dashboard purpose | Public access only; HTTP Basic Auth only if admin controls needed |
| Custom date range picker | Requires unbounded data storage, complex query UI, more API quota | Show "Last 30 days" clearly; v2 if users demand it |
| Multi-repo comparison mode | Doubles storage and complexity; OpenClaw is the single focus | Single-repo focus; Star History already owns comparison |
| Sentiment analysis on posts | NLP dependency; "positive/negative" labels on Reddit are unreliable | Show content + engagement; let users judge |
| Email / webhook notifications | Requires accounts, preferences, delivery infra — a different product | Display-only; v3 territory at earliest |
| Export to CSV / PDF | Low value relative to cost; this is a viewing dashboard | Future JSON API endpoint is better path |
| Historical data beyond 30 days | Unbounded SQLite growth; API history access is restricted on most platforms | 30-day rolling window, prune on schedule |
| Mobile app | Responsive web is sufficient for the audience | Responsive web; PWA scaffolded already |

---

## Feature Dependencies

```
GitHub data storage (migrations + models)
  → GitHub API fetcher job
    → Star/fork chart (time series)
    → Issue/PR activity chart
    → Commit frequency chart
    → Contributor chart
    → Latest release display
    → Delta indicators on hero metrics

Social data storage (migrations + models)
  → Per-platform fetcher jobs (X, Reddit, HN, YouTube)
    → Social card feeds
    → Engagement-weighted ranking
    → "Last updated" timestamps

Hero metrics row
  → GitHub data storage (needs at least one fetch)
  → Social data storage (needs at least one fetch)

Scheduled job runner (Solid Queue config)
  → All fetcher jobs (all data depends on scheduler)

Cross-platform correlation view (differentiator)
  → GitHub AND social data storage
  → Time-aligned data model (must be designed early even if feature ships later)

OpenGraph embed (differentiator)
  → Any working dashboard page (no data dependencies)
```

---

## MVP Recommendation

**Prioritize:**
1. GitHub data pipeline — models, migrations, GitHub API fetcher. Stars + forks + open issues + commit count.
2. Time-series charts with real data — replace static placeholder. Highest visual impact per line of code.
3. Hero metrics row — total stars, forks, open issues with 7-day deltas.
4. Hacker News feed — free, unauthenticated Algolia API; easiest social integration; proves the concept.
5. Reddit feed — OAuth app required but well-understood; second social platform.
6. "Last updated" display — builds trust in data freshness.

**Defer:**
- X/Twitter feed — API costs money; rate limits are aggressive. Build the abstraction, don't block milestone on credentials.
- YouTube feed — tight quota on free tier; implement last.
- Cross-platform correlation view — needs both pipelines stable first.
- OpenGraph embed — low effort, do it when data is real and worth sharing.
- Recency-weighted ranking formula — basic recency sort is fine for v1; blended score is v2 refinement.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Table stakes — GitHub metrics | HIGH | Stable norms; GitHub, OSS Insight, Star History all converge on same core |
| Table stakes — Social feeds | HIGH | Well-established card feed pattern across all social aggregation tools |
| Differentiators | MEDIUM | Gap analysis of known tools; competitor landscape may have shifted |
| Anti-features | HIGH | Grounded directly in PROJECT.md constraints |
| X/Twitter API availability | LOW | API pricing/tiers change frequently; must verify current pricing before implementation |
| HN Algolia API | HIGH | Free, unauthenticated, stable for years |
| Reddit API | MEDIUM | Policy changed significantly in 2023; verify current OAuth requirements |
| YouTube Data API v3 | MEDIUM | Stable but quota limits are real; verify free tier quota before implementation |
| GitHub REST API | HIGH | Well-documented, stable, 5,000 req/hr generous for this use case |
