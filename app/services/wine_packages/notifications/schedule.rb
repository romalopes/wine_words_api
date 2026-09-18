module WinePackages
  module Notifications
    # Creates the 15/5/0-day review-deadline reminders for a package.
    #
    # Idempotent by construction: each reminder is keyed by
    # (package, "wine_package_deadline", due date) and Notification.notify!
    # reuses an existing row, so the scheduler can run as often as it likes —
    # including on every arrival/completion event — without ever duplicating a
    # reminder.
    #
    # Rows are created undelivered (sent_at nil) and dated for the day they
    # should go out, so the recurring job can simply pick up
    # `Notification.undelivered.where(scheduled_date: ..Date.current)`.
    #
    # Reminders are skipped for finished business (completed, cancelled,
    # rejected) and for dates already in the past.
    class Schedule
      def self.call(package, at: Date.current)
        new(package, at: at).call
      end

      def initialize(package, at: Date.current)
        @package = package
        @at = at.to_date
      end

      # Returns the reminders that now exist (created or already present).
      def call
        return [] unless schedulable?

        due_dates.map { |date| create_reminder(date) }
      end

      private

      attr_reader :package, :at

      def schedulable?
        package.persisted? &&
          package.review_deadline.present? &&
          recipient.present? &&
          !package.completed? &&
          !package.cancelled? &&
          !package.rejected?
      end

      # The responsible reviewer; falls back to whoever recorded the package.
      def recipient
        package.reviewer || package.created_by
      end

      # Only reminders that are still in the future (or today) are worth having.
      def due_dates
        THRESHOLD_DAYS.map { |days| package.review_deadline - days }.select { |date| date >= at }
      end

      def create_reminder(date)
        Notification.notify!(
          recipient: recipient,
          type: DEADLINE_TYPE,
          notifiable: package,
          wine_package: package,
          scheduled_date: date,
          message: message_for(date)
        )
      end

      def message_for(date)
        # Days until the deadline *on the day the reminder goes out*, so the
        # 15/5/0-day reminders read exactly as intended.
        days_until_deadline = (package.review_deadline - date).to_i
        timing =
          if days_until_deadline.zero?
            "is today"
          else
            "is in #{days_until_deadline} #{'day'.pluralize(days_until_deadline)}"
          end
        producer = package.producer&.name || "Unknown producer"

        "#{producer}: #{package.pending_review_count} review(s) still pending; " \
          "the review deadline #{timing} (#{package.review_deadline})."
      end
    end
  end
end
