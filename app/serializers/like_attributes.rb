# Shared like fields for the hand-rolled serializers (Wine / Review / Article,
# list + detail). Keeps the payload shape identical everywhere:
#   likes_count (integer, always present) +
#   liked_by_current_user (boolean, true only when the preloaded set has the id).
module LikeAttributes
  extend ActiveSupport::Concern

  def like_fields(record, liked_ids = nil)
    {
      likes_count: record.try(:likes_count) || 0,
      liked_by_current_user: liked_ids ? liked_ids.include?(record.id) : false
    }
  end
end
