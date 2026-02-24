module DashboardHelper
  # Returns a human-friendly number (e.g., "1,247") or "—" if nil
  def format_number(value)
    return "—" if value.nil?
    ActiveSupport::NumberHelper.number_to_delimited(value.to_i)
  end

  # Returns a formatted date string (e.g., "Feb 23, 2026") or "—" if nil
  def format_date(value)
    return "—" if value.nil?
    begin
      date = value.is_a?(Date) ? value : Date.parse(value.to_s)
      date.strftime("%b %-d, %Y")
    rescue ArgumentError, TypeError
      "—"
    end
  end

  # Returns true if data hash is nil or empty (for empty state detection)
  def metric_empty?(data)
    data.nil? || data.empty?
  end

  # Converts a Julian Day Number (stored as a float/integer) back to a Date object
  def jd_to_date(jd_value)
    return nil if jd_value.nil?
    Date.jd(jd_value.to_i)
  rescue ArgumentError
    nil
  end

  # Returns "Updated X ago" or "No data yet" for last-updated timestamps
  def time_ago_or_never(timestamp)
    return "No data yet" if timestamp.nil?
    "Updated #{time_ago_in_words(timestamp)} ago"
  end
end
