# Polymorphic Like: one user can like a Wine, Review or Article exactly once.
#
# Uniqueness is enforced twice: a model validation for friendly errors and a
# database unique index (index_likes_on_user_and_likeable) as the final
# concurrency-safe guarantee. The counter_cache on :likeable keeps
# likes_count on the liked record in step without COUNT queries.
class Like < ApplicationRecord
  belongs_to :user
  belongs_to :likeable, polymorphic: true, counter_cache: :likes_count

  validates :user_id,
            uniqueness: {
              scope: [ :likeable_type, :likeable_id ]
            }
end
