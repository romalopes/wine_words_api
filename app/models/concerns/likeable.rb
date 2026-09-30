# Shared association for models that can be liked (Wine, Review, Article).
# Mirrors the Imageable pattern: one `has_many :likes, as: :likeable` include
# makes any future model likeable without touching the Like model.
module Likeable
  extend ActiveSupport::Concern

  included do
    has_many :likes,
             as: :likeable,
             dependent: :destroy
  end

  def liked_by?(user)
    return false if user.nil?

    likes.exists?(user_id: user.id)
  end
end
