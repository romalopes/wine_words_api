class Api::V1::UsersController < ApplicationController
  audit_actions assign_roles: "role_change", assign_subscription: "subscription_change"

  def log_description
    if action_name == "assign_roles"
      "Changed roles for user \"#{@target_user&.user_name}\"" \
        "#{audit_roles_diff}"
    else
      "Changed subscription for user \"#{@target_user&.user_name}\"" \
        "#{@assigned_subscription ? " to \"#{@assigned_subscription.name}\"" : ''}"
    end
  end

  def log_objects
    [current_user, @target_user, @assigned_subscription].compact
  end

  private

  def audit_roles_diff
    from = Array(@role_change_from).join(", ")
    to = Array(@role_change_to).join(", ")
    return "" if from.blank? || from == to

    " (from #{from} to #{to})"
  end

  def me
    current_sub = current_user.user_subscriptions.current.first
    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        user_name: current_user.user_name,
        roles: current_user.role_names,
        subscription: current_user.subscription ? { id: current_user.subscription.id, name: current_user.subscription.name } : nil,
        billing_provider: current_sub&.billing_provider,
        can_manage_billing: Billing.configured?,
        subscription_status: current_sub&.status,
      }
    }
  end

  # GET /api/v1/users/search?q=name-or-email
  def search
    return head(:forbidden) unless current_user.admin?

    query = params[:q].to_s.strip
    users =
      if query.blank?
        User.order(:name).limit(20)
      else
        User.where("name ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%")
            .order(:name).limit(20)
      end

    render json: users.map { |u| user_json(u) }
  end

  # GET /api/v1/roles — the full role list (id + human name), for role pickers.
  def roles
    render json: Role.order(:id).map { |r| { id: r.id, name: Role.names[r.name.to_s] || r.name.to_s } }
  end

  # PATCH /api/v1/users/:id/roles   body: { role_ids: [1,3] }
  def assign_roles
    return head(:forbidden) unless current_user.admin?

    user = User.find(params[:id])
    @target_user = user
    old_role_names = user.role_names
    role_ids = Array(params[:role_ids]).compact.map(&:to_i)
    user.user_roles.destroy_all
    role_ids.each { |rid| user.user_roles.create!(role_id: rid) }
    @role_change_from = old_role_names
    @role_change_to = user.reload.role_names
    render json: user_json(user.reload)
  end

  # PATCH /api/v1/users/:id/assign_subscription  body: { subscription_id: 2 }
  # Admin only. Applies the subscription and swaps the base access role
  # (Guest <-> Reader) while preserving privileged roles and history.
  def assign_subscription
    return head(:forbidden) unless current_user.admin?

    user = User.find(params[:id])
    @target_user = user
    subscription = Subscription.find(params[:subscription_id])
    @assigned_subscription = subscription

    if user.apply_subscription!(subscription)
      render json: user_json(user.reload)
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def user_json(user)
    {
      id: user.id,
      email: user.email,
      user_name: user.user_name,
      role_ids: user.role_ids,
      roles: user.role_names,
      subscription: user.subscription ? { id: user.subscription.id, name: user.subscription.name } : nil
    }
  end
end