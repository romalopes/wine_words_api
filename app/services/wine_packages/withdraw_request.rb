module WinePackages
  # Withdraws a pending (requested) producer request (issue #199 §2).
  #
  # Withdrawal is allowed while the request is still pending: once the
  # editorial side has accepted, dispatched or reviewed the package, the
  # package's fate belongs to Wine Words and the producer must contact the
  # editorial team instead. The package is cancelled through the normal
  # workflow (a cancelled package can be reopened to draft later), a
  # "withdrawn" event lands in the timeline and editors are notified.
  class WithdrawRequest
    def self.call(package, user:, at: Time.current)
      new(package, user: user, at: at).call
    end

    def initialize(package, user:, at:)
      @package = package
      @user = user
      @at = at
    end

    def call
      unless package.requested?
        raise Error, "only a pending (requested) package can be withdrawn"
      end

      package.withdraw!(by: user, at: at)
      Notifications::Lifecycle.deliver!(package, event: "withdrawn", actor: user)

      package
    end

    private

    attr_reader :package, :user, :at
  end
end
