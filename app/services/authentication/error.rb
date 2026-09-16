module Authentication
  # Safe, provider-independent authentication failure.
  #
  # `message` is always written for a human end-user and must never contain
  # token contents, provider secrets or stack traces — controllers render it
  # verbatim. `code` is a stable machine-readable reason the frontend may act
  # on; `status` is the HTTP status the controller should return.
  class Error < StandardError
    attr_reader :code, :status

    def initialize(message, code: :invalid_credential, status: :unauthorized)
      super(message)
      @code = code
      @status = status
    end

    def to_h
      { error: message, code: code }
    end
  end
end
