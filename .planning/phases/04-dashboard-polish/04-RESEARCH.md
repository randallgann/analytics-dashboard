# Phase 4: Dashboard Polish - Research

**Researched:** 2026-02-24
**Domain:** Rails view helpers, SQL delta queries, time-decay scoring, OpenGraph meta tags
**Confidence:** HIGH

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| DASH-01 | Hero metrics row showing total stars, forks, open issues with 7-day delta indicators | GitHubMetric already stores daily snapshots; delta = `latest_value - value_7_days_ago`; add `delta_value` helper + CSS for +/- indicator |
| DASH-03 | Social posts ranked by recency-weighted engagement score (fresh + engaging posts surface first) | HN-style time-decay formula: `score / (age_hours + 2)^1.8`; computed as a Ruby model scope, not in SQL; no migration needed |
| DASH-04 | OpenGraph meta tags for rich preview when dashboard URL is shared on Slack, Twitter, etc. | Rails `content_for :head` in layout `yield :head` pattern; `og:image` requires absolute URL via `asset_url` or `image_url` with `default_url_options` host set |
</phase_requirements>

---

## Summary

Phase 4 has three independent feature areas, each touching a different layer of the stack. None require
new gems, new database tables, or new background jobs. All work is pure view/model polish on the
existing Rails 8.1 + Propshaft + Stimulus codebase.

**DASH-01 (Hero metrics row with deltas):** The `GitHubMetric` model already records daily snapshots.
A 7-day delta is the difference between today's value and the value recorded 7 days ago. This is a
simple ActiveRecord query scoped to a date range. The delta helper formats the number with a sign
prefix and a colored CSS class (green for positive, red for negative). The hero row goes above the
existing sections, inside the `<% if @has_data %>` block.

**DASH-03 (Recency-weighted engagement ranking):** The existing `top_posts` scope ranks purely by
`score DESC`. The upgrade replaces this with a time-decay score — the same family of formula that
Hacker News uses. Computed in Ruby (not SQL) because SQLite's datetime arithmetic is clunky and the
post count is small (at most ~15 posts per platform, ~45 total). Add a `ranked_by_engagement` scope
or class method on `SocialPost` that fetches recent posts, applies the decay formula in Ruby, and
returns the sorted result. The "All" tab and each per-platform feed both use this.

**DASH-04 (OpenGraph meta tags):** Rails layout already has `<%= yield :head %>` in
`application.html.erb`. Add static OpenGraph tags directly in the layout `<head>` — they do not
need to vary per page since the dashboard is a single public page. The `og:image` requires an
absolute URL. The project uses Propshaft (not Sprockets). The correct approach is to place a static
image in `public/` (already has `icon.png`) or `app/assets/images/` and use `asset_url` in the
layout. Alternatively, `request.base_url` provides the host at render time without needing
`asset_host` configured.

**Primary recommendation:** Three separate plans — one per requirement. Each plan is small (< 1 hour
estimated). No new dependencies. No migrations. Pure model scope + view + CSS work.

---

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| ActiveRecord scopes | Rails 8.1 (already in use) | 7-day delta lookup on `github_metrics` | Already the data access pattern throughout the app |
| Ruby Array#sort_by | Ruby 3.3 stdlib | Recency-weighted sort after fetching social posts | Small dataset; no SQL needed; readable formula |
| Rails `content_for` / `yield` | Rails 8.1 (already in use) | Inject OpenGraph tags into layout `<head>` | Established Rails pattern; no new gem required |
| `asset_url` / `request.base_url` | Rails 8.1 (already in use) | Generate absolute URL for `og:image` | Propshaft-compatible; no `asset_host` config required in dev |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| CSS custom properties / inline style | N/A (already in use) | Green/red delta color indicators | Simpler than a JS component for static color coding |
| `content_tag` helper | Rails 8.1 (already in use) | Render delta badge HTML in `DashboardHelper` | Consistent with existing `render_social_card` pattern |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Ruby-side time-decay sort | SQL computed column or raw SQL ORDER BY | SQL datetime math in SQLite requires `julianday()` or `strftime`; error-prone and untestable; dataset is tiny so Ruby sort is equivalent performance |
| Static OG tags in layout | `meta-tags` gem (kpumuk/meta-tags) | Gem adds capability for per-page meta variation; overkill for a single-page dashboard with no user content; not in the Gemfile and adds a dependency |
| `image_url` helper for `og:image` | Full absolute string hardcoded | `image_url` picks up digest fingerprint from Propshaft; but requires `default_url_options` host set; `request.base_url + asset_path(...)` is simpler in a layout context |
| `og:image` from `public/` | Generate OG image server-side | Custom image generation (Puppeteer, `grover` gem) adds huge complexity; spec only asks for "title, description, and image" — a static logo image is sufficient |

**Installation:**
```bash
# No new gems needed
```

---

## Architecture Patterns

### Recommended Project Structure

Changes are surgical — existing files are modified, no new files created except CSS additions.

```
app/models/social_post.rb             # Add ranked_by_engagement class method
app/models/github_metric.rb           # Add delta_value class method + 7_days_ago scope
app/helpers/dashboard_helper.rb       # Add format_delta helper
app/controllers/dashboard_controller.rb  # Update @all_posts + per-platform feeds to use ranked_by_engagement; add @stars_delta, @forks_delta, @issues_delta
app/views/layouts/application.html.erb   # Add OpenGraph meta tags in <head>
app/views/dashboard/index.html.erb       # Add hero metrics row; update social feed to use ranked posts
app/assets/stylesheets/application.css   # Add .dash-hero-* and .dash-delta-* CSS classes
public/og-image.png                      # New: static 1200x630 OG image (or reuse existing icon.png)
test/models/social_post_test.rb          # Add ranked_by_engagement tests
test/models/github_metric_test.rb        # Add delta_value tests
test/helpers/dashboard_helper_test.rb    # Add format_delta tests
test/controllers/dashboard_controller_test.rb  # Add hero metrics + OG tag tests
```

### Pattern 1: 7-Day Delta on GitHubMetric

**What:** Compute the signed difference between today's snapshot and the snapshot 7 days ago.
**When to use:** For stars, forks, and open_issues on the hero row.

```ruby
# In app/models/github_metric.rb
def self.delta_value(metric_type, days: 7)
  current = for_metric(metric_type).order(recorded_on: :desc).first&.value
  past    = for_metric(metric_type)
              .where(recorded_on: ...(Date.today - days))
              .order(recorded_on: :desc)
              .first&.value
  return nil if current.nil? || past.nil?
  current - past
end
```

**Notes:**
- Returns `nil` if fewer than 7 days of data exist — the hero card must handle nil gracefully
- The existing `latest_value` scope already fetches the current value; `delta_value` uses the same
  pattern with a date-range filter
- `recorded_on:` uses a date column; the boundless range `...(Date.today - days)` selects records
  strictly before 7 days ago (the most recent of those is the "7 days ago" baseline)

### Pattern 2: Recency-Weighted Engagement Ranking

**What:** HN-style time-decay formula applied in Ruby after fetching posts from DB.
**When to use:** `SocialPost.ranked_by_engagement` replaces `top_posts` for the "All" tab and all
per-platform feeds in the social section.

The HN formula: `score = (points - 1) / (age_hours + 2)^gravity`

Adapted for this dashboard (engagement score can be 0; no need to subtract 1):

```ruby
# In app/models/social_post.rb
GRAVITY = 1.8

def self.ranked_by_engagement(limit: 10, since: 30.days.ago)
  posts = last_30_days.where.not(published_at: nil)
  posts.sort_by do |post|
    age_hours = [(Time.current - post.published_at) / 3600.0, 0].max
    engagement = post.score.to_f + (post.comment_count.to_f * 2)
    -(engagement / ((age_hours + 2)**GRAVITY))
  end.first(limit)
end

def self.ranked_by_engagement_for(platform, limit: 5)
  for_platform(platform).merge(ranked_by_engagement(limit: limit))
end
```

**Notes on the formula:**
- `score` for HN = upvotes; for Reddit = upvotes; for YouTube = view count (already in `score` col)
- YouTube view counts are orders of magnitude larger than HN/Reddit points; this causes YouTube to
  dominate the "All" feed when mixing platforms. **Mitigate by normalizing per-platform** or
  by NOT mixing YouTube into the "All" engagement-ranked feed (keep YouTube on its own tab only,
  sorted by recency). See Open Questions.
- `comment_count * 2` weights comments slightly higher than raw score (signals active discussion)
- `GRAVITY = 1.8` matches HN; higher value = faster decay; can be tuned
- `age_hours` of 0 is clamped to 0 to avoid negative age on future-dated posts
- The negative sign in `sort_by` gives descending order (highest engagement-decay score first)

**Simpler alternative (no cross-platform normalization needed):**

If mixing platforms in "All" tab is kept but YouTube normalization is deemed too complex, use
recency-only ranking for "All" (just `order(published_at: :desc)`) and apply engagement ranking
only within each platform's own tab.

### Pattern 3: OpenGraph Meta Tags in Layout

**What:** Static OG tags in `application.html.erb` `<head>`. Since the dashboard is a single-page
public app with no per-route content variation, static defaults are appropriate.

**When to use:** These tags activate whenever any link previewer (Slack, Twitter/X, Discord,
iMessage, Facebook) fetches the page.

```erb
<%# In app/views/layouts/application.html.erb, inside <head>, before yield :head %>

<%# OpenGraph / Social Sharing Meta Tags (DASH-04) %>
<meta property="og:type"        content="website">
<meta property="og:site_name"   content="OpenClaw Analytics">
<meta property="og:title"       content="OpenClaw Analytics Dashboard">
<meta property="og:description" content="GitHub metrics, Hacker News, Reddit, and YouTube mentions for OpenClaw — updated automatically.">
<meta property="og:url"         content="<%= request.base_url %>">
<meta property="og:image"       content="<%= request.base_url %>/og-image.png">
<meta property="og:image:width"  content="1200">
<meta property="og:image:height" content="630">

<%# Twitter Card (also read by Slack and many other previewers) %>
<meta name="twitter:card"        content="summary_large_image">
<meta name="twitter:title"       content="OpenClaw Analytics Dashboard">
<meta name="twitter:description" content="GitHub metrics, Hacker News, Reddit, and YouTube mentions for OpenClaw — updated automatically.">
<meta name="twitter:image"       content="<%= request.base_url %>/og-image.png">
```

**Notes:**
- `request.base_url` returns the origin (`https://yourdomain.com`) at render time — no asset_host
  config required
- The image lives in `public/og-image.png` (not in `app/assets/`) so it is served without Propshaft
  digest fingerprinting. Files in `public/` are always accessible at their literal path.
- The `yield :head` in `application.html.erb` is already present — OG tags go BEFORE it so views
  can override with `content_for :head` if ever needed in the future
- Required OG image dimensions: 1200x630px per Facebook/Slack/Twitter specs
- Minimum useful OG image: even `/icon.png` (which already exists in `public/`) works as a fallback,
  but Slack and Twitter render best with 1200x630. A simple 1200x630 banner can be created as a
  static PNG in the design tool of choice and dropped in `public/`

### Pattern 4: Hero Metrics Row Layout

**What:** A row of 3 stat cards above the existing content, showing stars + delta, forks + delta,
open issues + delta. These are "at a glance" summary numbers, NOT charts.

**When to use:** Immediately inside the `<% if @has_data %>` block, before the existing `#stars-forks`
section.

```erb
<%# Hero metrics row — DASH-01 %>
<section class="dash-hero-row">
  <%= render_hero_metric("Stars",       @stars_count,  @stars_delta,  "7d") %>
  <%= render_hero_metric("Forks",       @forks_count,  @forks_delta,  "7d") %>
  <%= render_hero_metric("Open Issues", @open_issues,  @issues_delta, "7d") %>
</section>
```

```ruby
# In DashboardHelper
def render_hero_metric(label, value, delta, period)
  content_tag(:div, class: "dash-hero-card") do
    label_el  = content_tag(:div, label, class: "dash-hero-label")
    value_el  = content_tag(:div, format_number(value), class: "dash-hero-value")
    delta_el  = format_delta(delta, period)
    safe_join([label_el, value_el, delta_el])
  end
end

def format_delta(delta, period)
  return content_tag(:div, "No baseline yet", class: "dash-delta dash-delta--neutral") if delta.nil?

  sign    = delta >= 0 ? "+" : ""
  css     = delta > 0 ? "dash-delta--positive" : (delta < 0 ? "dash-delta--negative" : "dash-delta--neutral")
  text    = "#{sign}#{format_number(delta)} this #{period}"
  content_tag(:div, text, class: "dash-delta #{css}")
end
```

### Anti-Patterns to Avoid

- **Computing deltas with raw SQL date math in SQLite:** `julianday()` and `strftime()` in SQLite
  differ from other RDBMS; Ruby Date arithmetic is safer and more testable.
- **Mixing YouTube view counts with HN/Reddit points in a single ranking:** View counts are 4-5
  orders of magnitude larger. A YouTube video with 10,000 views will always beat an HN post with
  200 points even with decay applied. Must normalize or keep platforms separate.
- **Using `image_path` instead of `image_url` for `og:image`:** `image_path` returns a relative
  path (`/assets/foo.png`). OpenGraph requires absolute URLs. Social crawlers reject relative paths.
- **Putting OG image in `app/assets/images/` and referencing via `image_url`:** Propshaft adds a
  digest fingerprint (`og-image-abc123.png`). The `og:image` URL must remain stable. Use `public/`
  instead.
- **No nil guard on delta when < 7 days of data exist:** First week after deployment has no baseline.
  `delta_value` returns `nil`; the view must display "—" or "No baseline yet", not crash.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Time-decay ranking formula | Custom weighted scoring system from scratch | HN's proven `score / (age+2)^1.8` formula | Battle-tested; tuneable via single gravity constant; simple to test |
| OpenGraph image generation | Server-side screenshot or canvas rendering | Static `public/og-image.png` | Spec says "title, description, and image" — a static logo/banner is sufficient and has zero runtime cost |
| Meta tag management | Custom meta tag DSL or helper library | Inline `<meta>` tags in layout | Single-page app; no per-route variation; `meta-tags` gem is overkill |
| Cross-platform engagement normalization | Complex ML or per-platform calibration | Keep platforms separate in ranked views | DASH-03 says "ranked by recency-weighted engagement" — per-platform tabs already exist; "All" tab can sort by recency only |

**Key insight:** All three requirements are presentation-layer polish. The data is already in the DB
from prior phases. This phase is about surfacing existing data better, not building new pipelines.

---

## Common Pitfalls

### Pitfall 1: Delta Returns Nil When < 7 Days of Data
**What goes wrong:** `delta_value("stars", days: 7)` returns `nil` if the project was just deployed
and only 0–6 days of snapshots exist. The view crashes with a NoMethodError on nil.
**Why it happens:** The baseline query (`where(recorded_on: ...(Date.today - 7))`) finds no records.
**How to avoid:** Always nil-guard in both the model method (return nil explicitly) and the helper
(`format_delta` renders "No baseline yet" when `delta.nil?`).
**Warning signs:** Any test that uses fresh fixture data dated today will trigger this case.

### Pitfall 2: YouTube View Count Dominates Cross-Platform Ranking
**What goes wrong:** In the "All" tab, a YouTube video with 50,000 views will always rank above an
HN post with 500 points, even with time decay, because the score magnitudes differ by 100x.
**Why it happens:** `score` stores the raw platform-native engagement number. YouTube stores view
counts (50,000+); HN/Reddit store upvote points (10–5,000 typical range).
**How to avoid:** Either (a) apply per-platform ranking within each tab but use `recent_first` order
for the "All" tab, or (b) normalize scores by platform (log normalization or percentile rank).
Option (a) is simpler and matches existing tab UX.
**Warning signs:** The "All" tab shows only YouTube posts.

### Pitfall 3: OpenGraph Image URL Uses Relative Path
**What goes wrong:** `og:image` renders as `/og-image.png` instead of `https://domain.com/og-image.png`.
Slack, Facebook, and Twitter crawlers reject relative paths and show no image preview.
**Why it happens:** Using `image_path` instead of `image_url`, or concatenating without the host.
**How to avoid:** Use `request.base_url + "/og-image.png"` in layout (always absolute) or configure
`default_url_options` host in production.
**Warning signs:** The og:image is a relative path when viewing page source.

### Pitfall 4: OG Image in `app/assets/images/` Gets Propshaft Fingerprinted
**What goes wrong:** Propshaft adds a digest to filenames (`og-image-abc123def.png`). The meta tag
renders with that hash. The hash changes on every deploy, but external crawlers cache the old URL
permanently. Old shares show broken images.
**Why it happens:** Propshaft fingerprints everything in `app/assets/` by design.
**How to avoid:** Put the OG image in `public/og-image.png`. Files in `public/` bypass Propshaft.
**Warning signs:** Viewing source shows `og-image-[hash].png` in the og:image content attribute.

### Pitfall 5: Engagement Ranking Fetches N+1 or Re-fetches Data
**What goes wrong:** `ranked_by_engagement` is called separately for each platform tab AND for "All",
causing 4 DB queries loading overlapping records.
**Why it happens:** Separate scope calls for HN, Reddit, YouTube, All.
**How to avoid:** Controller fetches `@ranked_posts = SocialPost.ranked_by_engagement(limit: 50)`
once and partitions in Ruby: `@hn_posts = @ranked_posts.select(&:hn?).first(5)` etc.
**Warning signs:** `to_sql` log shows 4+ nearly identical queries.

### Pitfall 6: `sort_by` Returns Array, Not ActiveRecord::Relation
**What goes wrong:** Code calls `SocialPost.ranked_by_engagement.where(platform: "hn")` and gets
`NoMethodError: undefined method 'where' for Array`.
**Why it happens:** `sort_by` returns a plain Array. You can't chain ActiveRecord scopes on it.
**How to avoid:** Fetch everything first, THEN sort, THEN select/partition in Ruby. Document on
the method that it returns Array, not Relation.
**Warning signs:** Chaining `.where` or `.limit` after `ranked_by_engagement` raises NoMethodError.

---

## Code Examples

Verified patterns from codebase and official sources:

### 7-Day Delta: Model Method

```ruby
# app/models/github_metric.rb
def self.delta_value(metric_type, days: 7)
  current = for_metric(metric_type).order(recorded_on: :desc).first&.value
  past    = for_metric(metric_type)
              .where(recorded_on: ...(Date.today - days))
              .order(recorded_on: :desc)
              .first&.value
  return nil if current.nil? || past.nil?
  current - past
end
```

### 7-Day Delta: Controller Assignment

```ruby
# app/controllers/dashboard_controller.rb (additions)
@stars_delta  = GitHubMetric.delta_value("stars")
@forks_delta  = GitHubMetric.delta_value("forks")
@issues_delta = GitHubMetric.delta_value("open_issues")
```

### Recency-Weighted Ranking: Model Method

```ruby
# app/models/social_post.rb
GRAVITY = 1.8

def self.ranked_by_engagement(limit: 50, since: 30.days.ago)
  candidates = where("published_at > ?", since).where.not(published_at: nil)
  candidates.sort_by do |post|
    age_hours  = [(Time.current - post.published_at) / 3600.0, 0].max
    engagement = post.score.to_f + (post.comment_count.to_f * 2)
    -(engagement / ((age_hours + 2)**GRAVITY))
  end.first(limit)
end
```

### Controller: Single-fetch + partition pattern (avoids Pitfall 5)

```ruby
# app/controllers/dashboard_controller.rb (Phase 4 version)
@ranked_posts    = SocialPost.ranked_by_engagement(limit: 50)
@hn_posts        = @ranked_posts.select(&:hn?).first(5)
@reddit_posts    = @ranked_posts.select(&:reddit?).first(5)
@youtube_posts   = @ranked_posts.select(&:youtube?).first(5)
@all_posts       = @ranked_posts.first(15)
```

### OpenGraph Meta Tags: Layout Head

```erb
<%# app/views/layouts/application.html.erb — inside <head> %>
<meta property="og:type"         content="website">
<meta property="og:site_name"    content="OpenClaw Analytics">
<meta property="og:title"        content="OpenClaw Analytics Dashboard">
<meta property="og:description"  content="GitHub metrics, Hacker News, Reddit, and YouTube mentions for OpenClaw — updated automatically.">
<meta property="og:url"          content="<%= request.base_url %>">
<meta property="og:image"        content="<%= request.base_url %>/og-image.png">
<meta property="og:image:width"  content="1200">
<meta property="og:image:height" content="630">
<meta name="twitter:card"        content="summary_large_image">
<meta name="twitter:title"       content="OpenClaw Analytics Dashboard">
<meta name="twitter:description" content="GitHub metrics, Hacker News, Reddit, and YouTube mentions for OpenClaw — updated automatically.">
<meta name="twitter:image"       content="<%= request.base_url %>/og-image.png">
```

### Hero Metrics Row: CSS Classes Needed

```css
/* app/assets/stylesheets/application.css — additions */

.dash-hero-row {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
  margin-bottom: 40px;
}

.dash-hero-card {
  background: #0f172a;
  border: 1px solid #1e293b;
  border-radius: 12px;
  padding: 20px 24px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}

.dash-hero-label {
  font-size: 12px;
  font-weight: 600;
  color: #64748b;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  margin-bottom: 6px;
}

.dash-hero-value {
  font-size: 36px;
  font-weight: 800;
  color: #f1f5f9;
  letter-spacing: -0.03em;
  line-height: 1;
  margin-bottom: 8px;
}

.dash-delta {
  font-size: 13px;
  font-weight: 600;
}

.dash-delta--positive { color: #34d399; }  /* green — matches existing cadence color */
.dash-delta--negative { color: #f87171; }  /* red — matches existing error color */
.dash-delta--neutral  { color: #475569; }  /* muted — matches existing empty-state color */
```

### Delta Helper

```ruby
# app/helpers/dashboard_helper.rb — additions
def format_delta(delta, period = "7d")
  return content_tag(:div, "No baseline yet", class: "dash-delta dash-delta--neutral") if delta.nil?

  sign = delta >= 0 ? "+" : ""
  css  = delta > 0 ? "positive" : (delta < 0 ? "negative" : "neutral")
  text = "#{sign}#{format_number(delta.to_i)} this #{period}"
  content_tag(:div, text, class: "dash-delta dash-delta--#{css}")
end
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `top_posts` scope: pure `ORDER BY score DESC` | `ranked_by_engagement`: time-decay sort | Phase 4 | Recent mid-score posts surface above old high-score posts |
| No hero metrics row | Hero row with 7-day deltas | Phase 4 | Growth visible at a glance without reading charts |
| No OpenGraph tags | OG + Twitter Card meta tags | Phase 4 | Rich previews on Slack, Discord, iMessage, X/Twitter |

**No deprecated approaches in scope for this phase.**

---

## Open Questions

1. **Cross-platform normalization in "All" tab**
   - What we know: YouTube `score` = view count (10k–1M range); HN/Reddit `score` = upvotes (10–5k range)
   - What's unclear: Does the product want YouTube in the "All" tab engagement ranking, or should "All" be recency-sorted only?
   - Recommendation: Default to "All tab uses recency order (`published_at DESC`), per-platform tabs use engagement ranking." This is safe, avoids normalization complexity, and matches user expectation (chronological "All" feed is common UX).

2. **OG image creation**
   - What we know: `public/icon.png` exists (app icon); no 1200x630 banner exists yet
   - What's unclear: Who creates the OG image? Is it acceptable to use the existing icon.png as a temporary fallback?
   - Recommendation: The plan should include a step to place a static `public/og-image.png`. The planner can note that the user must provide or approve a 1200x630 image. As a safe default, the plan can instruct copying `public/icon.png` to `public/og-image.png` — it will work (Slack/Twitter will display it, just square not rectangular). Document as "acceptable for v1."

3. **Hero row responsive layout**
   - What we know: The existing stat grid uses `grid-template-columns: repeat(2, 1fr)` on small screens
   - What's unclear: DASH-01 specifies a "row" — should it stack on small screens?
   - Recommendation: Follow the existing grid pattern: 1-column on mobile, 3-column on desktop (min-width: 640px). This is consistent with `.dash-grid-stats` behavior.

---

## Sources

### Primary (HIGH confidence)

- Project codebase (`app/models/github_metric.rb`) — confirmed `recorded_on` date column and existing `for_metric` / `latest_value` scopes
- Project codebase (`app/models/social_post.rb`) — confirmed `score`, `comment_count`, `published_at` columns available for ranking formula
- Project codebase (`app/views/layouts/application.html.erb`) — confirmed `<%= yield :head %>` already in `<head>`, ready for OG tags
- Project codebase (`app/assets/stylesheets/application.css`) — confirmed dark theme colors; `#34d399` = positive green, `#f87171` = error red
- Project codebase (`app/helpers/dashboard_helper.rb`) — confirmed `content_tag` / `safe_join` / `format_number` patterns in use

### Secondary (MEDIUM confidence)

- [HN Ranking Algorithm — righto.com](http://www.righto.com/2013/11/how-hacker-news-ranking-really-works.html) — confirmed `(P-1) / (T+2)^G` formula with G=1.8
- [Rails `ActionView::Helpers::AssetUrlHelper`](https://api.rubyonrails.org/classes/ActionView/Helpers/AssetUrlHelper.html) — confirmed `image_url` returns absolute URL; requires `asset_host` or explicit host option
- [Propshaft asset pipeline overview — judoscale.com](https://judoscale.com/blog/how-propshaft-works) — confirmed Propshaft fingerprints assets in `app/assets/`; `public/` files are not fingerprinted
- WebSearch: OpenGraph `og:image` must be absolute URL (HTTP/HTTPS scheme required per OGP spec)

### Tertiary (LOW confidence)

- WebSearch: Twitter/X time decay applies "half-life" every 6 hours — suggests GRAVITY=1.8 is directionally appropriate but no authoritative source for this project's specific use case

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all libraries are already in use in the codebase; no new dependencies
- Architecture: HIGH — patterns mirror existing code (model scopes, helpers, CSS classes)
- Delta formula: HIGH — straightforward date subtraction on existing schema
- Engagement ranking formula: MEDIUM — HN formula is documented and widely used; cross-platform normalization is open question
- OpenGraph tags: HIGH — OGP spec is stable; `request.base_url` is a well-known Rails pattern; `public/` bypass of Propshaft is confirmed behavior
- Pitfalls: HIGH — derived directly from codebase inspection (nil guard, N+1, Array vs Relation)

**Research date:** 2026-02-24
**Valid until:** 2026-03-24 (stable Rails/Ruby patterns; 30-day window)
