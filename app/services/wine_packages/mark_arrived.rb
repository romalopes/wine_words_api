module WinePackages
  # Records that a package physically arrived and starts the review clock.
  #
  #   * arrived_at defaults to now;
  #   * review_deadline defaults to ONE CALENDAR MONTH after arrival
  #     (Date#>> handles year rollover) and is never overwritten once set, so a
  #     deadline supplied up front (or via `deadline:`) always wins;
  #   * the status moves to "arrived" through the normal transition guard;
  #   * the 15/5/0-day reminders are scheduled (idempotently).
  #
  # Raises WinePackage::InvalidTransition when the current status cannot reach
  # "arrived" (e.g. an already completed package).
  class MarkArrived
    def self.call(package, at: Time.current, deadline: nil)
      new(package, at: at, deadline: deadline).call
    end

    def initialize(package, at: Time.current, deadline: nil)
      @package = package
      @at = at
      @deadline = deadline
    end

    def call
      package.review_deadline = deadline if deadline.present?
      package.mark_arrived!(at: at)

      # Reminders are keyed by their due date, so scheduling again is a no-op.
      Notifications::Schedule.call(package, at: at.to_date)

      package
    end

    private

    attr_reader :package, :at, :deadline
  end
end
