class Subscription < ApplicationRecord
  has_many :subscription_subscription_features, dependent: :destroy
  has_many :subscription_features, through: :subscription_subscription_features
  # Use restrict_with_error so a plan with assigned users or history cannot be
  # hard-deleted (soft-delete via active:false / visible:false instead). The
  # dependent callbacks must not clear these BEFORE the destroy guard runs.
  has_many :users, dependent: :restrict_with_error
  has_many :user_subscriptions, dependent: :restrict_with_error

  accepts_nested_attributes_for :subscription_subscription_features, allow_destroy: true

  validates :name, :slug, presence: true, uniqueness: true
  validates :is_default, uniqueness: true, if: :is_default?
  validates :currency, presence: true
  validates :monthly_price_cents, :yearly_price_cents,
            numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  scope :visible,  -> { where(visible: true) }
  scope :active,   -> { where(active: true) }
  scope :paid,     -> { where.not(yearly_price_cents: [nil, 0]).or(where.not(monthly_price_cents: [nil, 0])) }
  scope :by_position, -> { order(:position, :name) }

  before_destroy :prevent_destroy_if_in_use, prepend: true

  def free?
    (monthly_price_cents.nil? || monthly_price_cents.zero?) &&
      (yearly_price_cents.nil? || yearly_price_cents.zero?)
  end

  def self.default
    find_by(is_default: true)
  end

  private

  def prevent_destroy_if_in_use
    return unless users.exists? || user_subscriptions.exists?

    errors.add(:base, "Cannot delete a subscription that has users or subscription history")
    throw(:abort)
  end
end