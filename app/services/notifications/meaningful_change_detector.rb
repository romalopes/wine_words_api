# frozen_string_literal: true

# Decides whether a content change is worth notifying followers about.
#
# Only a small allowlist of public fields is "meaningful" — timestamp churn,
# search-vector maintenance, deadline-only changes, analytics counters and
# draft edits never publish events. Draft -> published transitions are handled
# by the caller (they are events even when no other field changed).
module Notifications
  module MeaningfulChangeDetector
    # Public display fields per model. Additions must be reviewed: every entry
    # here becomes a follower notification on edit.
    MEANINGFUL_FIELDS = {
      "Review" => %w[title comment score drink_from drink_to drink_plus vintage_id],
      "Article" => %w[title abstract body],
      "Wine" => %w[name color closure alcohol_percentage volume_ml description producer_id],
      "Vintage" => %w[year],
      "Producer" => %w[name description producer_type founded_year]
    }.freeze

    module_function

    # True when a saved record's changes include at least one meaningful field.
    # `record.saved_changes` must be called on the record after save.
    def meaningful_update?(record)
      fields = MEANINGFUL_FIELDS[record.class.name]
      return false if fields.nil?

      record.saved_changes.keys.any? { |attr| fields.include?(attr) }
    end
  end
end