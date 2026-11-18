# One contact-form submission (IDENTITY_209).
#
# The list endpoint deliberately omits the body: the inbox only needs the
# sender, category, subject, status and timestamps, and message bodies must
# never ride along with bulk responses. The detail endpoint includes it.
class ContactMessageSerializer
  def initialize(contact_message, include_message: false)
    @contact_message = contact_message
    @include_message = include_message
  end

  def as_json
    payload = {
      id: @contact_message.id,
      name: @contact_message.name,
      email: @contact_message.email,
      contact_type: @contact_message.contact_type,
      subject: @contact_message.subject,
      status: @contact_message.status,
      read: @contact_message.read?,
      archived: @contact_message.archived?,
      read_at: iso(@contact_message.read_at),
      archived_at: iso(@contact_message.archived_at),
      created_at: iso(@contact_message.created_at),
      updated_at: iso(@contact_message.updated_at)
    }

    payload[:message] = @contact_message.message if @include_message
    payload
  end

  private

  def iso(time)
    time&.iso8601
  end
end
