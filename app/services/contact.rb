# Public contact form (IDENTITY_209).
#
#   Contact::Messages::Submit        validate + persist a public submission
#   ContactMessages::Recipients      parse CONTACT_NOTIFICATION_EMAILS
#   ContactMessages::NotifyStaff     in-app notification per Editor/Admin
#
# No parallel messaging domain: everything lands on ContactMessage and reuses
# the existing Notification / mail / job infrastructure.
module Contact
  # Raised when a contact submission cannot be processed for a reason the
  # controller must translate into a public-safe response.
  class Error < StandardError; end
end
