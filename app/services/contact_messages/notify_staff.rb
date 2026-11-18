# Tells the editorial team that a public contact message arrived
# (IDENTITY_209 Phase 2).
#
# Every active Editor and Admin account gets one in-app Notification, visible
# immediately (delivered_at is stamped) and linked to the Contact Messages
# detail page. Soft-deleted accounts and every other role are excluded.
#
# Idempotency is a database guarantee: the partial unique index on
# (recipient_id, contact_message_id, notification_type) rejects a second row
# for the same message, so a retried job cannot duplicate notifications.
#
# Never raises for a single recipient: the message is already committed, and
# one broken recipient must not stop the rest from being notified.
module ContactMessages
  class NotifyStaff
    NOTIFICATION_TYPE = "contact_message_received".freeze
    STAFF_ROLES = %w[Admin Editor].freeze

    def self.call(contact_message:)
      new(contact_message: contact_message).call
    end

    def initialize(contact_message:)
      @contact_message = contact_message
    end

    def call
      recipients.each do |recipient|
        notify(recipient)
      rescue StandardError => e
        Rails.logger.warn(
          "[ContactMessages::NotifyStaff] message #{contact_message.id} " \
          "recipient #{recipient.id}: #{e.class}: #{e.message}"
        )
      end
    end

    private

    attr_reader :contact_message

    def recipients
      @recipients ||= User.not_deleted
                          .joins(:roles)
                          .where(roles: { name: STAFF_ROLES })
                          .distinct
                          .to_a
    end

    def notify(recipient)
      notification = Notification.create!(
        recipient: recipient,
        notification_type: NOTIFICATION_TYPE,
        contact_message: contact_message,
        notifiable: contact_message,
        delivered_at: Time.current,
        message: message,
        target_path: target_path,
        target_label: target_label
      )

      Notifications::WebPushDeliveryJob.perform_later(notification.id)
    rescue ActiveRecord::RecordNotUnique
      # A concurrent or retried run already told this recipient.
      nil
    end

    def message
      "#{contact_message.name} sent a #{contact_type_label} message: #{contact_message.subject}"
    end

    def contact_type_label
      contact_message.contact_type.tr("_", " ")
    end

    def target_path
      "/settings/contact-messages/#{contact_message.id}"
    end

    def target_label
      "Contact message from #{contact_message.name}"
    end
  end
end
