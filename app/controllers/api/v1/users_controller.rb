class Api::V1::UsersController < ApplicationController
  def me
    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        name: current_user.name,
        roles: current_user.role_names
      }
    }
  end

  # GET /api/v1/users/search?q=name-or-email
  def search
    return head(:forbidden) unless current_user.super_admin?

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
    return head(:forbidden) unless current_user.super_admin?

    user = User.find(params[:id])
    role_ids = Array(params[:role_ids]).compact.map(&:to_i)
    user.user_roles.destroy_all
    role_ids.each { |rid| user.user_roles.create!(role_id: rid) }
    render json: user_json(user.reload)
  end

  private

  def user_json(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      role_ids: user.role_ids,
      roles: user.role_names
    }
  end
end