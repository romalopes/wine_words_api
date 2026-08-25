class Tag < ApplicationRecord
  has_many :article_tags, dependent: :destroy
  has_many :articles, through: :article_tags

  validates :name, presence: true, uniqueness: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug

  def self.find_or_create_by_name(name)
    name = name.to_s.strip
    return nil if name.blank?

    find_or_create_by!(name: name) do |tag|
      tag.slug = name.parameterize
    end
  end

  private

  def generate_slug
    self.slug ||= name.to_s.parameterize
  end
end