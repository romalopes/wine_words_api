module Trade
  module Submissions
    # Tells the editorial team that a new public trade submission arrived.
    #
    # Every Editor and Admin account is told twice:
    #   * an in-app Notification, delivered immediately so the bell and the
    #     /notifications feed show it at once (a web-push job is queued too);
    #   * one email per recipient (deliver_later) — never a shared To/CC list,
    #     so staff addresses are not disclosed to each other.
    #
    # The submitter is excluded: an editor who submits through the public form
    # should not be told about their own package. Soft-deleted accounts are
    # excluded as well.
    #
    # Idempotent per (package, type, day, recipient): the notifications unique
    # index makes a retried call reuse the existing row, and no email is queued
    # for a recipient who already has one.
    #
    # Never raises: the package is already committed when this runs, so a mail
    # or push failure must not turn a successful submission into an error.
    class NotifyStaff
      NOTIFICATION_TYPE = "trade_submission_received".freeze
      STAFF_ROLES = %w[Admin Editor].freeze

      def self.call(package:, submitter: nil)
        new(package: package, submitter: submitter).call
      end

      def initialize(package:, submitter: nil)
        @package = package
        @submitter = submitter
      end

      def call
        recipients.each do |recipient|
          notify(recipient)
        rescue StandardError => e
          # Best-effort per recipient: one broken address must not stop the
          # others from being told.
          Rails.logger.warn(
            "[Trade::Submissions::NotifyStaff] package #{package&.id} " \
            "recipient #{recipient&.id}: #{e.class}: #{e.message}"
          )
        end
      end

      private

      attr_reader :package

      def recipients
        @recipients ||= begin
          scope = User.not_deleted
                      .joins(:roles)
                      .where(roles: { name: STAFF_ROLES })
                      .distinct
          scope = scope.where.not(id: @submitter.id) if @submitter
          scope.to_a
        end
      end

      def notify(recipient)
        identity = {
          recipient: recipient,
          notification_type: NOTIFICATION_TYPE,
          wine_package: package,
          scheduled_date: Date.current
        }
        # Already told (retry / repeated call): the row carries the email too.
        return if Notification.exists?(identity)

        notification = Notification.create!(
          identity.merge(
            notifiable: package,
            delivered_at: Time.current,
            message: message,
            target_path: target_path,
            target_label: target_label
          )
        )

        TradeSubmissionsMailer.new_submission(package.id, recipient.id).deliver_later
        Notifications::WebPushDeliveryJob.perform_later(notification.id)
      rescue ActiveRecord::RecordNotUnique
        # A concurrent delivery won the race — the recipient is already told.
        nil
      end

      def message
        "#{company_name} submitted #{wine_count_label} for review " \
          "(submission ##{package.id})."
      end

      def wine_count_label
        count = package.wine_package_items.size
        count == 1 ? "1 wine" : "#{count} wines"
      end

      def company_name
        contact["company_name"].presence || contact["contact_name"].presence ||
          "A trade submitter"
      end

      def contact
        @contact ||= (package.contact_snapshot || {}).stringify_keys
      end

      # Staff-only page that shows the submission (contact details, wines and
      # the shared/internal timeline).
      def target_path
        "/admin/trade/packages/#{package.id}"
      end

      def target_label
        "Trade submission ##{package.id}"
      end
    end
  end
end
