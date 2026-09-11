class LogObject < ApplicationRecord
  belongs_to :log
  belongs_to :object, polymorphic: true, optional: true

  validates :object_type, :object_id, presence: true
end
