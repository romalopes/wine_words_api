# Presentation helpers for publication deadlines (issue #185).
#
# The model computes `overdue?` and `days_until_deadline`; these helpers only
# format them. Keeping the wording in one place means the article and review
# lists always describe a deadline the same way, and the label is always
# paired with a symbol so colour is never the only signal.
module DeadlinesHelper
  # "Due 21 Oct 2026", "Due today", "Overdue by 3 days" or "No deadline".
  # Callers render this for drafts only; the helper itself stays status-agnostic
  # so it can also describe an archived record's retained date.
  def deadline_label(record)
    return "No deadline" if record.deadline.blank?

    days = record.days_until_deadline
    return "Due today" if days.zero?
    return "Overdue by #{pluralize(days.abs, 'day')}" if days.negative?

    "Due #{record.deadline.strftime('%-d %b %Y')}"
  end

  # Semantic state used for styling: overdue / today / upcoming / none.
  def deadline_state(record)
    return "none" if record.deadline.blank?

    days = record.days_until_deadline
    return "overdue" if days.negative?
    return "today" if days.zero?

    "upcoming"
  end

  # A deadline badge for drafts. Published and archived records render nothing:
  # they keep their stored date but are no longer operationally due.
  def deadline_badge(record)
    return if record.status != "draft"

    state = deadline_state(record)
    content_tag(:span, class: "deadline-badge deadline-badge--#{state}") do
      safe_join([ deadline_icon(state), deadline_label(record) ], " ")
    end
  end

  # Decorative icon; the adjacent text carries the meaning for screen readers.
  def deadline_icon(state)
    symbol =
      case state
      when "overdue" then "⚠"
      when "today" then "⏰"
      when "upcoming" then "📅"
      else "—"
      end
    content_tag(:span, symbol, "aria-hidden": "true")
  end
end
