module WinePackages
  module Notifications
    # Producer lifecycle notifications (issue #199 §5/§8).
    #
    # Every notification is an in-app row (delivered_at stamped on creation);
    # email delivery stays a separate concern, owned by whatever job reads the
    # undelivered rows. A failing notification NEVER rolls back the package
    # transition that caused it — deliver! is best-effort per recipient.
    #
    # Idempotent per (recipient, package, type, day): a retried job or a
    # concurrent request reuses the existing row instead of duplicating it.
    class Lifecycle
      SUBMITTED  = "wine_package_submitted"
      WITHDRAWN  = "wine_package_withdrawn"
      ACCEPTED   = "wine_package_accepted"
      REJECTED   = "wine_package_rejected"
      ARRIVED    = "wine_package_arrived"
      COMPLETED  = "wine_package_completed"

      def self.deliver!(package, event:, actor: nil)
        new(package, event: event, actor: actor).deliver!
      end

      def initialize(package, event:, actor: nil)
        @package = package
        @event = event.to_s
        @actor = actor
      end

      def deliver!
        case event
        when "requested"
          notify(editors, type: SUBMITTED, message: "#{producer_name} submitted a review request (#{items_count} wine(s)).")
        when "withdrawn"
          notify(editors, type: WITHDRAWN, message: "#{producer_name} withdrew a pending review request.")
        when "accepted"
          notify(producer_side, type: ACCEPTED, message: "Your review request for #{producer_name} was accepted.")
        when "rejected"
          reason = package.rejection_reason.present? ? ": #{package.rejection_reason}" : ""
          notify(producer_side, type: REJECTED, message: "Your review request for #{producer_name} was rejected#{reason}.")
        when "arrived"
          notify(producer_side, type: ARRIVED, message: "Your package for #{producer_name} arrived — reviews are starting.")
        when "completed"
          notify(producer_side, type: COMPLETED, message: "Reviews for your #{producer_name} package are complete.")
        end
      rescue StandardError => e
        # A notification must never break the workflow transition.
        Rails.logger.warn(
          "[WinePackages::Notifications::Lifecycle] delivery failed " \
          "(package #{package&.id}, event #{event}): #{e.class}: #{e.message}"
        )
      end

      private

      attr_reader :package, :event, :actor

      # Editors and admins receive the producer-side submissions; the assigned
      # reviewer already gets deadline reminders through Schedule.
      def editors
        User.joins(:roles).where(roles: { name: %w[Admin Editor] }).distinct
      end

      # The producer side of the conversation: whoever submitted the request
      # plus every active owner/manager member of the producer. The actor is
      # excluded (they performed the action).
      def producer_side
        recipients = [ package.requested_by ].compact +
          package.producer.producer_memberships.managing.includes(:user).map(&:user).compact
        recipients.uniq - [ actor ].compact
      end

      def notify(recipients, type:, message:)
        recipients.each do |recipient|
          row = Notification.find_or_create_by!(
            recipient: recipient,
            notification_type: type,
            wine_package: package,
            scheduled_date: Date.current
          ) do |notification|
            notification.notifiable = package
            notification.delivered_at = Time.current
            notification.message = message
          end

          # Reused row from an earlier delivery: make sure it is visible.
          row.update!(delivered_at: Time.current, message: message) if row.delivered_at.nil?
        end
      end

      def producer_name
        package.producer&.name || "your producer"
      end

      def items_count
        package.wine_package_items.size
      end
    end
  end
end
