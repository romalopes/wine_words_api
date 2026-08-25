class Category < ApplicationRecord
  has_many :articles, dependent: :nullify

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug

  private

  def generate_slug
    self.slug ||= name.to_s.parameterize
  end
end