class Follow < ApplicationRecord
  ALLOWED_TYPES = %w[Producer Wine Review Article].freeze

  belongs_to :user
  belongs_to :followable, polymorphic: true

  validates :followable_type, inclusion: { in: ALLOWED_TYPES }
  validates :user_id, uniqueness: { scope: [:followable_type, :followable_id] }

  scope :for_type, ->(type) { where(followable_type: type) }
  scope :recent, -> { order(created_at: :desc) }

  # Ensure followable exists and is followable (published for Review/Article)
  validate :followable_is_visible

  private

  def followable_is_visible
    return unless followable
    return if user&.wine_manager?

    case followable
    when Review, Article
      unless followable.class.visible_to(user).exists?(followable.id)
        errors.add(:followable, "is not visible to you")
      end
    when Producer, Wine
      # Producers and Wines are always followable if they exist
    end
  end
end