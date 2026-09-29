class WineGrape < ApplicationRecord
  # Search vectors that index this record's values (see SearchVectorDependent).
  include SearchVectorDependent
  SEARCH_VECTOR_ATTRIBUTES = [].freeze

  belongs_to :wine
  belongs_to :grape

  validates :grape_id, uniqueness: { scope: :wine_id }

  private

  # Every review of every vintage of the linked wine.
  def search_reindex_targets
    { "Review" => self.class.review_ids_for_wines(Wine.where(id: wine_id)) }
  end

  # The link is the input: it is what puts the grape in the vector, so adding
  # one matters as much as removing one.
  def search_reindex_on_link_change?
    true
  end
end
