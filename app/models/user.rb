class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_many :reviews, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles

  # Every new user starts with the "Guest" role unless roles were
  # explicitly assigned (e.g. seeded admins).
  after_create :assign_default_role

  def role?(key)
    roles.exists?(name: Role.names[key] || key)
  end

  def super_admin?
    role?(:super_user)
  end

  # Only Super Users and Reviewers may create/edit/delete wines.
  def wine_manager?
    super_admin? || role?(:reviewer)
  end

  def role_names
    roles.map { |r| Role.names[r.name.to_s] || r.name.to_s }.sort
  end

  def jwt_payload
    { name: name, roles: role_names }
  end

  private

  def assign_default_role
    roles << Role.find_or_create_by!(name: "Guest") if roles.empty?
  end
end