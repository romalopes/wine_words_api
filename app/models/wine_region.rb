class WineRegion < ApplicationRecord
  # Search vectors that index this record's values (see SearchVectorDependent).
  include SearchVectorDependent
  SEARCH_VECTOR_ATTRIBUTES = [].freeze

  self.table_name = "wine_regions"

  belongs_to :wine
  belongs_to :region

  validates :wine_id, uniqueness: { scope: :region_id }

  private

  # Every review of every vintage of the linked wine.
  def search_reindex_targets
    { "Review" => self.class.review_ids_for_wines(Wine.where(id: wine_id)) }
  end

  # The link is the input: it is what puts the region in the vector, so adding
  # one matters as much as removing one.
  def search_reindex_on_link_change?
    true
  end
end
