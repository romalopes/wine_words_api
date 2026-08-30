class Country < ApplicationRecord
  has_many :grapes, dependent: :nullify
  has_many :regions, dependent: :destroy

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :code, presence: true, uniqueness: { case_sensitive: false },
                   format: { with: /\A[A-Za-z]{2}\z/, message: "must be a 2-letter ISO code" },
                   length: { is: 2 }
end