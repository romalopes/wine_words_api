# Keeps other records' search vectors in step with this record's values.
#
# A vector indexes associations, not just the row's own columns: rename a wine
# and every review of it still claims the old name; re-tag an article and the
# tag is invisible until the article is saved again. Those edits happen on the
# *referenced* record, which is why they cannot be caught by the vector owner's
# own `before_save :update_search_vector`.
#
# Including models declare what they contribute and who indexes it:
#
#   SEARCH_VECTOR_ATTRIBUTES = %w[name].freeze   # editing these makes vectors stale
#   def search_reindex_targets                   # -> { "Review" => [ids] }
#     { "Review" => self.class.review_ids_for_wines(wines) }
#   end
#
# Join rows (WineRegion, WineGrape) carry no attributes of their own — the link
# *is* the input — so they set `SEARCH_VECTOR_ATTRIBUTES = [].freeze` and
# override `search_reindex_on_link_change?` to true, which makes the link's
# creation reindex as well as its removal.
#
# The repair itself runs in SearchReindexJob, so a rename that touches thousands
# of reviews never blocks the request that caused it.
module SearchVectorDependent
  extend ActiveSupport::Concern

  # Attributes this record contributes to a vector. Models without any (join
  # rows) still get the callback: their create/destroy changes the link.
  SEARCH_VECTOR_ATTRIBUTES = [].freeze

  included do
    after_commit :enqueue_search_reindex, if: :search_reindex_needed?
  end

  class_methods do
    # The reviews that index any of these vintages.
    def review_ids_for_vintages(vintages_scope)
      Review.where(vintage_id: vintages_scope.select(:id)).pluck(:id)
    end

    # The reviews that index any vintage of these wines — the shape every
    # wine-level dependency (producer, region, grape, country, link row) needs.
    def review_ids_for_wines(wines_scope)
      review_ids_for_vintages(Vintage.where(wine_id: wines_scope.select(:id)))
    end
  end

  private

  # A saved change to a watched attribute, or a link row whose existence is
  # itself the indexed value.
  def search_reindex_needed?
    return true if search_reindex_on_link_change?

    self.class::SEARCH_VECTOR_ATTRIBUTES.any? do |attribute|
      saved_changes.key?(attribute.to_s)
    end
  end

  # Whether this row *being there* (or no longer) is what a vector names. Only
  # join rows: for everything else the watched attributes above decide.
  def search_reindex_on_link_change?
    false
  end

  def enqueue_search_reindex
    search_reindex_targets.each do |model_name, ids|
      next if ids.blank?

      SearchReindexJob.perform_later(model_name, ids)
    end
  end
end
