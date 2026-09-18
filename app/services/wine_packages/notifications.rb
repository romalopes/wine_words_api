module WinePackages
  # Deadline reminders for a wine package.
  #
  # Reminders are created (never emailed) here. Delivery is a separate concern
  # owned by the recurring job, which reads the undelivered rows this service
  # produces — keeping the scheduler free of any mailer dependency.
  module Notifications
    # How many days before the review deadline a reminder is raised, and the
    # notification_type stored on every reminder.
    THRESHOLD_DAYS = [ 15, 5, 0 ].freeze
    DEADLINE_TYPE = "wine_package_deadline".freeze
  end
end
