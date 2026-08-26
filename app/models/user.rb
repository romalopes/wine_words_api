class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_many :reviews, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles

  def role?(key)
    roles.exists?(name: Role.names[key] || key)
  end

  def super_admin?
    role?(:super_user)
  end

  def role_names
    roles.map { |r| Role.names[r.name.to_s] || r.name.to_s }.sort
  end

  def jwt_payload
    { name: name, roles: role_names }
  end
end