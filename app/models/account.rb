class Account < ApplicationRecord
  belongs_to :user
  has_one :account_address, dependent: :destroy, class_name: "AccountAddress"
  accepts_nested_attributes_for :account_address, update_only: true

  validates :first_name, :last_name, length: { maximum: 80 }, allow_nil: true
  validates :phone, length: { maximum: 40 }, allow_nil: true
  validate :date_of_birth_in_the_past, if: -> { date_of_birth.present? }

  # Shape used by GET /api/v1/account — always present, even before the
  # account row is created, so the settings form has a stable shape.
  def self.build_default(user)
    user.account || new(user: user, account_address: AccountAddress.new)
  end

  private

  def date_of_birth_in_the_past
    errors.add(:date_of_birth, "must be in the past") if date_of_birth >= Date.current
  end
end
