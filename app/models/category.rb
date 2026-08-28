class Category < ApplicationRecord
  has_many :articles, dependent: :nullify
  has_many :wines, dependent: :nullify
  has_many :reviews, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  SORT_ORDER_COLUMNS = {
    for_wine: :sort_order_wine,
    for_review: :sort_order_review,
    for_article: :sort_order_article,
  }.freeze

  before_validation :generate_slug
  before_create :assign_sort_orders

  private

  # Places the new category after the last one for each enabled type.
  def assign_sort_orders
    SORT_ORDER_COLUMNS.each do |flag, column|
      next unless public_send(flag)

      max = Category.maximum(column) || 0
      self[column] = max + 1
    end
  end

  def generate_slug
    self.slug ||= name.to_s.parameterize
  end
end