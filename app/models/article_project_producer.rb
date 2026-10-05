class ArticleProjectProducer < ApplicationRecord
  belongs_to :article_project
  belongs_to :producer

  validates :producer_id, uniqueness: { scope: :article_project_id }
  validate :confirmation_requires_contact

  before_validation :mark_contacted_when_confirmed

  private

  def mark_contacted_when_confirmed
    self.contacted = true if request_confirmed?
  end

  def confirmation_requires_contact
    return unless request_confirmed? && !contacted?

    errors.add(:contacted, "must be true when request is confirmed")
  end
end