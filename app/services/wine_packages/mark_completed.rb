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
    def self.call(package, at: Time.current)
      new(package, at: at).call
    end

    def initialize(package, at: Time.current)
      @package = package
      @at = at
    end

    def call
      package.auto_completed = false
      package.mark_completed!(at: at)
      package
    end

    private

    attr_reader :package, :at
  end
end
