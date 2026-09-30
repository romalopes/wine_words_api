# Batch lookup for "did current_user like these records?" without N+1.
#
# Usage:
#   liked_ids = Likes.liked_ids_for(wines, current_user) # => Set of wine ids
#   WineListSerializer.new(w, base_url, vintage_counts, liked_ids: liked_ids)
class Likes
  def self.liked_ids_for(records, user)
    liked_map_for(records, user).values.first || Set.new
  end

  # Returns { "Wine" => Set(ids), "Review" => Set(ids) } for mixed collections.
  def self.liked_map_for(records, user)
    result = Hash.new { |h, k| h[k] = Set.new }
    return result if user.nil?

    Array(records).group_by { |r| r.class.name }.each do |type, items|
      ids = items.map(&:id).compact.uniq
      next if ids.empty?

      liked = Like.where(user_id: user.id, likeable_type: type, likeable_id: ids).pluck(:likeable_id)
      result[type] = liked.to_set
    end
    result
  end
end
