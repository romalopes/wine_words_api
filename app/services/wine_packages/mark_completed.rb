module WinePackages
  # Deliberate completion by a reviewer ("Mark Package Reviewed").
  #
  # Unlike WinePackages::CheckCompletion this completes even when
  # review_requested items are still pending, and it records that the decision
  # was human: auto_completed stays false, so a later review edit can never
  # reopen it behind the reviewer's back.
  #
  # Raises WinePackage::InvalidTransition unless the package is "arrived" or
  # "reviewing".
  class MarkCompleted
    def self.call(package, at: Time.current, actor: nil)
      new(package, at: at, actor: actor).call
    end

    def initialize(package, at: Time.current, actor: nil)
      @package = package
      @at = at
      @actor = actor
    end

    def call
      package.auto_completed = false
      package.mark_completed!(at: at, actor: actor)

      # The producer side learns the review work is finished (issue #199).
      # Delivered in-app; a failure never rolls the transition back.
      Notifications::Lifecycle.deliver!(package, event: "completed", actor: actor)

      package
    end

    private

    attr_reader :package, :at, :actor
  end
end
