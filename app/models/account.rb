class Account < ApplicationRecord
  belongs_to :user, inverse_of: :account
  include SearchVectorDependent
  SEARCH_VECTOR_ATTRIBUTES = %w[first_name last_name].freeze
  before_validation :normalize_names
  validates :first_name, :last_name, presence: true, on: :profile
  has_one :account_address, dependent: :destroy, class_name: "AccountAddress"
  accepts_nested_attributes_for :account_address, update_only: true

  validates :first_name, :last_name, length: { maximum: 80 }, allow_nil: true
  validates :phone, length: { maximum: 40 }, allow_nil: true
  validate :date_of_birth_in_the_past, if: -> { date_of_birth.present? }

  # Persist a missing profile defensively for legacy records.
  def self.build_default(user)
    user.account || user.create_account!
  end

  private

  def normalize_names
    self.first_name = first_name.to_s.strip.presence
    self.last_name = last_name.to_s.strip.presence
  end

  def search_reindex_targets
    { "Review" => Review.where(user_id: user_id).pluck(:id), "Article" => Article.where(user_id: user_id).pluck(:id) }
  end

  def date_of_birth_in_the_past
    errors.add(:date_of_birth, "must be in the past") if date_of_birth >= Date.current
  end
end
