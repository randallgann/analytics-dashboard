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

  # Renders a social post card with platform badge, title link, and metadata row
  def render_social_card(post)
    content_tag(:div, class: "dash-social-card") do
      badge = content_tag(:div, class: "dash-social-badge dash-social-badge--#{post.platform}") do
        if post.hn?
          "Y".html_safe
        elsif post.reddit?
          "R".html_safe
        else
          "YT".html_safe
        end
      end

      content = content_tag(:div, class: "dash-social-content") do
        # Use hn_discussion_url as fallback for HN posts without a URL (e.g., Ask HN)
        # Do NOT use "#" for HN — the model provides hn_discussion_url for this exact case
        card_url = post.url || (post.hn? ? post.hn_discussion_url : "#")
        title_link = link_to(post.title, card_url, target: "_blank", rel: "noopener", class: "dash-social-title")

        meta_parts = []
        if post.youtube?
          meta_parts << content_tag(:span, "#{format_number(post.score)} views")
        else
          meta_parts << content_tag(:span, "#{post.score} pts")
        end
        meta_parts << content_tag(:span, "#{post.comment_count} comments") unless post.youtube?
        meta_parts << content_tag(:span, post.author) if post.author.present?
        meta_parts << content_tag(:span, "r/#{post.subreddit}") if post.reddit? && post.subreddit.present?
        meta_parts << content_tag(:span, "#{time_ago_in_words(post.published_at)} ago") if post.published_at.present?

        meta = content_tag(:div, safe_join(meta_parts, " "), class: "dash-social-meta")

        safe_join([title_link, meta])
      end

      safe_join([badge, content])
    end
  end
end
