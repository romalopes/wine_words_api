class ProducerMembership < ApplicationRecord
  belongs_to :user
  belongs_to :producer
  belongs_to :created_by, class_name: 'User', optional: true

  validates :user_id, uniqueness: { scope: :producer_id, message: 'is already linked to this producer' }
end