module WinePackages
  # Submits a producer-managed draft as a review request (issue #199 §2).
  #
  #   * only a draft can be submitted — the workflow guard rejects anything
  #     else with the same message in the console and in the API;
  #   * wine lines are optional, allowing package/shipping details to be
  #     submitted before the producer has identified individual wines;
  #   * the requester is recorded on `requested_by`, and both `submitted_at`
  #     and `requested_at` are stamped;
  #   * the "requested" timeline event is recorded by the transition itself,
  #     so status change and audit stay transactionally consistent;
  #   * editors are notified through WinePackages::Notifications::Lifecycle —
  #     a notification failure never rolls back the submission.
  class SubmitRequest
    def self.call(package, user:, at: Time.current)
      new(package, user: user, at: at).call
    end

    def initialize(package, user:, at:)
      @package = package
      @user = user
      @at = at
    end

    def call
      raise Error, "only a draft package can be submitted" unless package.draft?

      package.submit_request!(at: at, actor: user)
      Notifications::Lifecycle.deliver!(package, event: "requested", actor: user)

      package
    end

    private

    attr_reader :package, :user, :at
  end
end
