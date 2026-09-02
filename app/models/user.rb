class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :jwt_authenticatable, jwt_revocation_strategy: JwtDenylist

  has_many :reviews, dependent: :destroy
  has_many :user_roles, dependent: :destroy
  has_many :roles, through: :user_roles
  belongs_to :subscription, optional: true
  has_many :user_subscriptions, dependent: :destroy

  # Every new user starts with the "Guest" role and the FREE subscription
  # unless roles were explicitly assigned (e.g. seeded admins).
  after_create :assign_default_role
  after_create :assign_default_subscription

  # Base access roles are mutually exclusive and controlled by the subscription:
  #   FREE subscription  -> "Guest"
  #   any paid subscription -> "Reader"
  # Privileged roles (Reviewer, Super User, Editor) are independent of the
  # subscription and are NEVER touched by subscription changes.
  BASE_ROLES = ["Guest", "Reader"].freeze

  def role?(key)
    roles.exists?(name: Role.names[key] || key)
  end


  def super_admin?
    role?(:super_user)
  end

  def reviewer?
    role?(:reviewer)
  end

  # Super Users, Reviewers and Editors may manage wines/producers —
  # anywhere a Reviewer is allowed, an Editor is allowed too.
  def wine_manager?
    super_admin? || role?(:editor)
  end

  def role_names
    roles.map { |r| Role.names[r.name.to_s] || r.name.to_s }.sort
  end

  def jwt_payload
    { name: name, roles: role_names }
  end

  # Apply a subscription to this user. Switches the base access role
  # (Guest <-> Reader) while preserving privileged roles (Reviewer, Super
  # User, Editor). Records subscription history via user_subscriptions.
  #
  # Paid -> paid upgrades change features only and skip role writes entirely.
  def apply_subscription!(new_subscription)
    return if new_subscription.nil?

    new_base = new_subscription.free? ? "Guest" : "Reader"
    current_base = roles.where(name: BASE_ROLES).pick(:name)
    changing_base = (current_base != new_base)

    transaction do
      user_subscriptions.current.update_all(ended_at: Time.current)
      user_subscriptions.create!(subscription: new_subscription, started_at: Time.current, status: :active)

      if changing_base
        roles.delete(Role.where(name: BASE_ROLES))
        roles << Role.find_or_create_by!(name: new_base)
      end

      update!(subscription: new_subscription)
    end
  end

  private

  def assign_default_role
    roles << Role.find_or_create_by!(name: "Guest") if roles.empty?
  end

  def assign_default_subscription
    default_sub = Subscription.default
    return unless default_sub
    return if subscription_id.present?

    update_column(:subscription_id, default_sub.id)
    user_subscriptions.create!(subscription: default_sub, started_at: Time.current, status: :active)
  end
end