class ArticleProjectNotebook < ApplicationRecord
  belongs_to :article_project_vintage

  validates :title, presence: true, length: { maximum: 255 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  before_validation :normalize_title

  scope :ordered, -> { order(:position, :id) }

  private

  def normalize_title
    self.title = title.to_s.strip
  end
end