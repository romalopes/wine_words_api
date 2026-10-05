class ArticleProjectVintage < ApplicationRecord
  BOTTLE_CONDITIONS = %w[not_assessed good damaged leaking other].freeze

  belongs_to :article_project
  belongs_to :vintage

  validates :vintage_id, uniqueness: { scope: :article_project_id }
  validates :bottle_condition, inclusion: { in: BOTTLE_CONDITIONS }
  validate :receipt_fields_are_consistent

  before_validation :apply_receipt_defaults

  private

  def apply_receipt_defaults
    if received?
      self.date_received ||= Date.current
    elsif will_save_change_to_received? && !received?
      self.date_received = nil
      self.bottle_condition = "not_assessed"
    end
  end

  def receipt_fields_are_consistent
    if date_received.present? && !received?
      errors.add(:date_received, "requires received to be true")
    end
    errors.add(:date_received, "cannot be in the future") if date_received.present? && date_received > Date.current
    if bottle_condition != "not_assessed" && !received?
      errors.add(:bottle_condition, "requires received to be true")
    end
  end
end