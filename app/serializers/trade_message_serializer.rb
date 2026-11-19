# Trade conversation message (IDENTITY_206 Phase 8). Internal notes are only
# ever serialised for staff — the query feeding the serializer is already
# scoped, this is defence in depth.
class TradeMessageSerializer
  def initialize(message, base_url = nil, staff: false)
    @message = message
    @base_url = base_url
    @staff = staff
  end

  def as_json(*)
    {
      id: @message.id,
      sender_type: @message.sender_type,
      sender_name: sender_name,
      body: @message.body,
      internal_note: @staff ? @message.internal_note? : false,
      created_at: @message.created_at&.iso8601
    }
  end

  private

  # When a submitter views the thread, staff messages always show a neutral
  # "Wine Words Team" identity — never expose individual editor/admin names
  # to the submitter side of the conversation.
  def sender_name
    return "Wine Words Team" if !@staff && @message.sender_type.in?(%w[editor admin])
    return "Wine Words" if @message.sender_type.in?(%w[editor admin]) && @message.sender.nil?
    return "Submitter" if @message.sender.nil?

    @message.sender.display_name.presence || @message.sender.email
  end
end