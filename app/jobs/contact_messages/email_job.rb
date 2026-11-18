# Emails ONE configured contact recipient about a new contact message
# (IDENTITY_209 Phase 2).
#
# One job per recipient keeps retries safe: a bounced/failed address is retried
# on its own and the other recipients never receive a duplicate.
#
# The message row already exists when this runs (the public endpoint commits
# before enqueuing), so a delivery failure can never lose the submission.
module ContactMessages
  class EmailJob < ApplicationJob
    queue_as :default

    # Transient provider/network failures are retried with backoff; the message
    # remains persisted and visible in the inbox regardless of the outcome.
    retry_on StandardError, wait: :polynomially_longer, attempts: 4

    # The message was deleted (or the job outlived the retention window): the
    # work is no longer meaningful.
    discard_on ActiveRecord::RecordNotFound

    def perform(contact_message_id, recipient_email)
      message = ContactMessage.find(contact_message_id)

      ContactMessagesMailer.notification(message.id, recipient_email).deliver_now

      Rails.logger.info(
        "[ContactMessages::EmailJob] message #{message.id} emailed to a configured recipient"
      )
    end
  end
end
