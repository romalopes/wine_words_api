module WinePackages
  # Single source of truth for AUTOMATIC completion.
  #
  # Invoked whenever the set of fulfilled review-requested items can change:
  #   * a linked review is published / unpublished   (Review after_save)
  #   * an item's review link changes or it is removed (WinePackageItem)
  #   * the API actions that add, update or delete items
  #
  # Rules (spec §14 / §51):
  #   * only items with review_requested: true are ever considered — a wine that
  #     was not requested for review never blocks anything, and a package with
  #     no requested items is never auto-completed;
  #   * a package auto-completes only once it has arrived (or is being
  #     reviewed) AND every requested item has a PUBLISHED review;
  #   * an auto-completed package reopens when that stops being true (a review
  #     was unpublished, an item was added);
  #   * a deliberate completion (WinePackages::MarkCompleted) is never undone:
  #     it leaves auto_completed false.
  #
  # Idempotent and safe to call repeatedly.
  class CheckCompletion
    # Only these statuses may be auto-completed. A draft/announced/in-transit
    # package is never completed for you, even if some reviews already exist.
    AUTO_COMPLETABLE_STATUSES = %w[arrived reviewing].freeze

    def self.call(package)
      new(package).call
    end

    def initialize(package)
      @package = package
    end

    def call
      return package if package.nil? || !package.persisted?
      # A cancelled or rejected package is finished business.
      return package if package.cancelled? || package.rejected?

      if auto_completable?
        complete!
      elsif reopenable?
        reopen!
      end

      package
    end

    private

    attr_reader :package

    def auto_completable?
      AUTO_COMPLETABLE_STATUSES.include?(package.status) &&
        package.review_requested_items.exists? &&
        package.reviews_complete?
    end

    # Only reopen work that was completed automatically — a reviewer's explicit
    # "Mark Package Reviewed" must survive a later review edit.
    def reopenable?
      package.completed? &&
        package.auto_completed? &&
        package.pending_review_count.positive?
    end

    def complete!
      # Set the provenance before saving so mark_completed! persists both in one
      # write (mark_completed! never touches the flag itself).
      package.auto_completed = true
      package.mark_completed!
      Notifications::Schedule.call(package)
    end

    def reopen!
      # reopen! clears auto_completed and moves the package to "reviewing".
      package.reopen!
    end
  end
end
