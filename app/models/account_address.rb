class AccountAddress < ApplicationRecord
  belongs_to :account
  belongs_to :country, optional: true

  validates :street_address, :city, :state, :postal_code, length: { maximum: 200 }, allow_nil: true
end
