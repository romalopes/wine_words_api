# Shared publication-deadline behaviour for Article and Review (issue #185).
#
# Rules:
#   * `deadline` is a nullable date. An explicitly supplied value is never
#     overwritten — only a nil deadline is defaulted.
#   * The fallback is the creation date + 14 calendar days. A Review created
#     from a WinePackage inherits that package's deadline through its creation
#     path; this concern only provides the last-resort default.
#   * `overdue?` is true only while the record is still a draft, has a
#     deadline, and the deadline is earlier than today (application timezone).
#     A deadline of today is "due today", not overdue. Published and archived
#     records keep their stored date but are never flagged.
module Deadlineable
  extend ActiveSupport::Concern

  # Calendar days used when nothing else supplies a deadline.
  DEFAULT_DEADLINE_DAYS = 14

  included do
    before_validation :apply_default_deadline, if: :new_record?
  end

  # Last-resort fallback: today + 14 calendar days. Never overrides an
  # explicitly supplied (or service-inherited) deadline.
  def apply_default_deadline
    self.deadline ||= Date.current + DEFAULT_DEADLINE_DAYS
  end

  # Only drafts can be overdue. Published/archived keep their date but are
  # never flagged — a published article has met (or missed) its deadline and
  # needs no further warning.
  def overdue?
    return false if status != "draft"

    deadline.present? && deadline < Date.current
  end

  # Negative once the deadline has passed. Nil when there is no deadline.
  def days_until_deadline
    return nil if deadline.blank?

    (deadline - Date.current).to_i
  end
end
