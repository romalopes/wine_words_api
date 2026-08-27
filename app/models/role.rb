class Role < ApplicationRecord
  # Rails 8.1 string-backed enum: the stored column is a human-readable name
  # ("Super User"), while the enum keys give convenient predicates/scopes.
  enum :name, {
    super_user: "Super User",
    editor: "Editor",
    reviewer: "Reviewer",
    reader: "Reader",
    guest: "Guest"
  }

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles

  validates :name, presence: true, uniqueness: true
end
