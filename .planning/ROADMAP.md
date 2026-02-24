# Roadmap: OpenClaw Analytics Dashboard

## Overview

Transform the existing Rails 8.1 placeholder dashboard into a live analytics product by building data pipelines one vertical slice at a time. Phase 1 delivers a working GitHub metrics pipeline end-to-end — from API client to time-series charts — while establishing the shared infrastructure every subsequent phase depends on. Phase 2 adds the social feed architecture with Hacker News and Reddit. Phase 3 integrates YouTube into the proven social pipeline with quota-aware scheduling. Phase 4 upgrades presentation with engagement ranking, delta indicators, and sharing metadata. X/Twitter is deferred to v2 pending API cost approval.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation + GitHub Pipeline** - SQLite WAL mode, shared HTTP client, GitHub API end-to-end with real chart data (completed 2026-02-24)
- [ ] **Phase 2: Social Feed — HN and Reddit** - SocialPost model, card feed UI, Hacker News and Reddit ingest jobs
- [ ] **Phase 3: YouTube Integration** - YouTube video cards with quota-aware scheduling (4x/day max)
- [ ] **Phase 4: Dashboard Polish** - Engagement ranking, delta indicators, OpenGraph sharing tags

## Phase Details

### Phase 1: Foundation + GitHub Pipeline
**Goal**: Real GitHub data flows into the dashboard — time-series charts show actual star, fork, issue, and commit history
**Depends on**: Nothing (first phase)
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, INFRA-05, GH-01, GH-02, GH-03, GH-04, GH-05, GH-06, GH-07, GH-08, GH-09, DASH-02, DASH-05, DASH-06
**Success Criteria** (what must be TRUE):
  1. Visiting the dashboard shows real star and fork count charts with 30 days of data (not placeholders)
  2. Open/closed issue counts, PR activity, commit frequency, contributor count, and latest release info are all visible with real data
  3. Background job runs every 6 hours and new GitHub data appears in charts without manual intervention
  4. The dashboard is publicly accessible with no login prompt and loads in under 3 seconds
  5. Old records older than 30 days are automatically pruned daily
**Plans**: 3 plans

Plans:
- [x] 01-01-PLAN.md -- Infrastructure + data foundation (Octokit gem, GitHubMetric model, GithubClient service, WAL verification)
- [x] 01-02-PLAN.md -- Background jobs + scheduling (GithubMetricJob, DataRetentionJob, recurring.yml)
- [x] 01-03-PLAN.md -- Dashboard UI (dark theme, charts, sticky nav, empty states, visual verification)

### Phase 2: Social Feed — HN and Reddit
**Goal**: A card-based social feed shows recent Hacker News and Reddit posts mentioning OpenClaw, updated every 2 hours
**Depends on**: Phase 1
**Requirements**: HN-01, HN-02, HN-03, HN-04, RDT-01, RDT-02, RDT-03, RDT-04, SOC-01, SOC-02, SOC-03
**Success Criteria** (what must be TRUE):
  1. The dashboard displays a feed of recent HN posts with title, points, comment count, author, date, and a clickable link to the HN discussion
  2. The dashboard displays a feed of recent Reddit posts with title, upvotes, comment count, subreddit, author, date, and a clickable link to the Reddit post
  3. Each social card shows a platform badge (HN or Reddit) identifying its source
  4. Each feed section shows a "last updated" timestamp so stale data is visible
  5. If one platform's fetch job fails, the other platform's feed continues to display normally
**Plans**: 3 plans

Plans:
- [ ] 02-01-PLAN.md -- Data foundation (SocialPost model + migration, HnClient service, RedditClient service)
- [ ] 02-02-PLAN.md -- Background jobs + scheduling (HnSocialJob, RedditSocialJob, DataRetentionJob extension, recurring.yml)
- [ ] 02-03-PLAN.md -- Dashboard UI (Stimulus tabs, social card feed, platform badges, empty states, visual verification)

### Phase 3: YouTube Integration
**Goal**: YouTube video cards appear in the social feed, fetched at most 4 times per day to stay within the free API quota
**Depends on**: Phase 2
**Requirements**: YT-01, YT-02, YT-03, YT-04
**Success Criteria** (what must be TRUE):
  1. The dashboard displays YouTube videos mentioning OpenClaw with title, view count, channel name, published date, and a clickable link to the video
  2. YouTube cards display the YouTube platform badge alongside HN and Reddit cards
  3. The YouTube fetch job runs no more than 4 times per day and does not exhaust the free API quota
**Plans**: TBD

Plans:
- [ ] 03-01: TBD

### Phase 4: Dashboard Polish
**Goal**: The dashboard surfaces the most engaging recent content first and communicates growth at a glance — hero metrics with deltas, ranked social feed, and rich link previews when shared
**Depends on**: Phase 3
**Requirements**: DASH-01, DASH-03, DASH-04
**Success Criteria** (what must be TRUE):
  1. A hero metrics row at the top of the dashboard shows total stars, forks, and open issues with 7-day delta indicators (e.g., "+142 stars this week")
  2. Social posts across all platforms are ranked by recency-weighted engagement — recent high-engagement posts surface above old low-engagement posts
  3. Sharing the dashboard URL on Slack, Twitter, or any link previewer shows a rich embed with title, description, and image
**Plans**: TBD

Plans:
- [ ] 04-01: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 -> 2 -> 3 -> 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + GitHub Pipeline | 3/3 | Complete    | 2026-02-24 |
| 2. Social Feed — HN and Reddit | 0/3 | Not started | - |
| 3. YouTube Integration | 0/? | Not started | - |
| 4. Dashboard Polish | 0/? | Not started | - |
