module Trade
  module Messages
    # Creates a conversation line on a trade submission and tells the OTHER side.
    #
    # Direction matters:
    #   * a submitter/guest message notifies the editorial team (Editor/Admin);
    #   * an editorial message notifies the submitter.
    #
    # Every recipient gets two channels:
    #   * an in-app Notification, delivered immediately (plus a web-push job), and
    #   * one email addressed to that recipient individually.
    #
    # Guest submissions have no User to notify in-app, so their contact email
    # from contact_snapshot receives the message instead.
    #
    # Best-effort: the message row is the source of truth and is always created;
    # a failing mail/push never rolls the conversation back.
    class Send
      NOTIFICATION_TYPE = "trade_message_received".freeze
      STAFF_ROLES = %w[Admin Editor].freeze

      def self.call(package:, sender:, body:)
        new(package: package, sender: sender, body: body).call
      end

      def initialize(package:, sender:, body:)
        @package = package
        @sender = sender
        @body = body
      end

      def call
        message = nil
        ActiveRecord::Base.transaction do
          message = package.wine_package_messages.create!(
            sender: sender,
            sender_type: sender_type,
            body: body,
            internal_note: false
          )

          package.wine_package_events.create!(
            event_type: "message_sent",
            actor: sender,
            visibility: "shared",
            occurred_at: Time.current,
            metadata: { wine_package_message_id: message.id }
          )
        end

        notify_recipients(message)
        message
      end

      private

      attr_reader :package, :sender, :body

      def staff_sender?
        sender.present? && sender.catalogue_manager?
      end

      def sender_type
        return "submitter" unless staff_sender?

        # Admins stay "admin", editors "editor" — the UI shows who replied.
        sender.admin? ? "admin" : "editor"
      end

      # Staff messages go to the submitter; submitter messages go to the staff.
      def notify_recipients(message)
        if staff_sender?
          notify_submitter(message)
        else
          notify_staff(message)
        end
      rescue StandardError => e
        Rails.logger.warn(
          "[Trade::Messages::Send] package #{package.id}: #{e.class}: #{e.message}"
        )
      end

      def notify_staff(message)
        staff_recipients.each do |recipient|
          next if recipient.id == sender&.id

          deliver(recipient, message, target_path: "/admin/trade/packages/#{package.id}")
        end
      end

      def notify_submitter(message)
        submitter = package.submitter
        if submitter.present?
          deliver(submitter, message, target_path: "/trade/my-packages/#{package.id}")
        else
          # Guest submission: no account to notify in-app, so the contact email
          # receives the message directly.
          email_guest_contact(message)
        end
      end

      def staff_recipients
        User.not_deleted
            .joins(:roles)
            .where(roles: { name: STAFF_ROLES })
            .distinct
            .to_a
      end

      def deliver(recipient, message, target_path:)
        return if recipient.nil?

        notification = Notification.find_or_create_by!(
          recipient: recipient,
          notification_type: NOTIFICATION_TYPE,
          wine_package: package,
          scheduled_date: Date.current
        ) do |row|
          row.notifiable = package
          row.delivered_at = Time.current
          row.message = notification_body(message)
          row.target_path = target_path
          row.target_label = "Trade submission ##{package.id}"
        end

        notification.update!(delivered_at: Time.current) if notification.delivered_at.nil?
        PackageMessagesMailer.new_message(package, recipient, message).deliver_later
        Notifications::WebPushDeliveryJob.perform_later(notification.id)
      rescue StandardError => e
        Rails.logger.warn(
          "[Trade::Messages::Send] recipient #{recipient&.id} failed: #{e.class}: #{e.message}"
        )
      end

      def email_guest_contact(message)
        return if contact_email.blank?

        PackageMessagesMailer.new_message_to_contact(package, message).deliver_later
      rescue StandardError => e
        Rails.logger.warn(
          "[Trade::Messages::Send] contact email failed: #{e.class}: #{e.message}"
        )
      end

      def contact_email
        (package.contact_snapshot || {})["email"].presence
      end

      def notification_body(message)
        "#{sender_label} sent you a message on \"Trade submission ##{package.id}\":\n" \
          "#{message.body.to_s[0, 2000]}"
      end

      def sender_label
        return "Wine Words" if sender.blank?

        sender.display_name.presence || sender.email
      end
    end
  end
end
