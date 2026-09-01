class ProducerGrape < ApplicationRecord
  belongs_to :producer
  belongs_to :grape

  validates :producer_id, uniqueness: { scope: :grape_id }
end
