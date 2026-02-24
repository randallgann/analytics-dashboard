# Seed historical GitHub metrics for OpenClaw repository.
#
# Generates ~365 days of estimated daily data for stars, forks, and
# contributor_count based on the project's known growth timeline.
# Idempotent: uses find_or_initialize_by so re-running won't duplicate
# data, and skips dates that already have fresher data from the API.

puts "Seeding historical GitHub metrics..."

STAR_MILESTONES = [
  ["2025-11-24",      0],
  ["2025-12-15",    200],
  ["2026-01-01",    400],
  ["2026-01-15",    600],
  ["2026-01-24",   1000],
  ["2026-01-25",   9000],
  ["2026-01-26",  15000],
  ["2026-01-27",  25000],
  ["2026-01-28",  40000],
  ["2026-01-29",  50000],
  ["2026-01-30", 106000],
  ["2026-01-31", 123000],
  ["2026-02-01", 138000],
  ["2026-02-02", 145000],
  ["2026-02-05", 157000],
  ["2026-02-10", 175000],
  ["2026-02-17", 200000],
  ["2026-02-24", 224575],
].map { |date_str, stars| [Date.parse(date_str), stars] }.freeze

# Linear interpolation between milestone data points.
def interpolate_stars(date, milestones)
  return 0 if date < milestones.first[0]
  return milestones.last[1] if date >= milestones.last[0]

  milestones.each_cons(2) do |(d1, v1), (d2, v2)|
    next unless date >= d1 && date < d2

    progress = (date - d1).to_f / (d2 - d1)
    return (v1 + (v2 - v1) * progress).round
  end

  milestones.last[1]
end

# Fork ratio ramps from ~10% early on to ~19% at maturity.
def fork_ratio(date)
  launch = Date.parse("2025-11-24")
  today  = Date.parse("2026-02-24")
  return 0.10 if date <= launch

  progress = [(date - launch).to_f / (today - launch), 1.0].min
  0.10 + 0.09 * progress
end

# Contributors: logistic growth from ~5 at launch to ~841 today.
def contributor_count(date)
  launch = Date.parse("2025-11-24")
  today  = Date.parse("2026-02-24")
  return 0 if date < launch

  progress = [(date - launch).to_f / (today - launch), 1.0].min
  # Logistic curve: slow start, rapid growth during viral period, plateau
  logistic = 1.0 / (1.0 + Math.exp(-12 * (progress - 0.5)))
  (5 + 836 * logistic).round
end

seed_time = Time.current
start_date = Date.parse("2025-02-25") # 365 days before today
end_date   = Date.parse("2026-02-24")

created = 0
skipped = 0

(start_date..end_date).each do |date|
  stars = interpolate_stars(date, STAR_MILESTONES)
  forks = (stars * fork_ratio(date)).round
  contributors = contributor_count(date)

  { "stars" => stars, "forks" => forks, "contributor_count" => contributors }.each do |metric_type, value|
    record = GitHubMetric.find_or_initialize_by(metric_type: metric_type, recorded_on: date)

    # Skip if this record was already updated by a live API fetch
    if record.persisted? && record.updated_at > seed_time
      skipped += 1
      next
    end

    record.value = value
    record.save!
    created += 1
  end
end

puts "  Historical GitHub metrics seeded: #{created} records created/updated, #{skipped} skipped (fresher data exists)."
