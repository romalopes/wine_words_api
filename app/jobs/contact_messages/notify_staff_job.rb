# Creates the in-app notifications for a new contact message
# (IDENTITY_209 Phase 2).
#
# Async so the public request never waits on notification fan-out, and
# retry-safe because ContactMessages::NotifyStaff relies on the partial unique
# index on (recipient_id, contact_message_id, notification_type).
module ContactMessages
  class NotifyStaffJob < ApplicationJob
    queue_as :default

    retry_on StandardError, wait: :polynomially_longer, attempts: 4

    discard_on ActiveRecord::RecordNotFound

    def perform(contact_message_id)
      message = ContactMessage.find(contact_message_id)

      ContactMessages::NotifyStaff.call(contact_message: message)
    end
  end
end
