class UserRolesController < ActionController::Base
  layout "application"

  # NOTE: we intentionally do NOT include the RequireLogin concern here.
  # It registers callbacks with `only: [:new, :edit, :create, :update, :destroy]`
  # and this controller has none of those actions, which Rails 7.1+ rejects
  # ("The new action could not be found for the :require_login callback").
  before_action :set_current_user
  before_action :super_admin!

  def set_current_user
    @current_user = warden.user(:user) if respond_to?(:warden) && warden
  end

  def index
    @roles = Role.order(:id)
    query = params[:q].to_s.strip
    @users =
      if query.blank?
        User.order(:name).limit(20)
      else
        User.where("name ILIKE ? OR email ILIKE ?", "%#{query}%", "%#{query}%")
            .order(:name).limit(20)
      end
  end

  # PATCH /user_roles/:user_id
  def update
    user = User.find(params[:user_id])
    role_ids = Array(params[:user][:role_ids]).compact.map(&:to_i)
    user.user_roles.destroy_all
    role_ids.each { |rid| user.user_roles.create!(role_id: rid) }
    redirect_to user_roles_path(q: params[:q]), notice: "Roles updated for #{user.name || user.email}."
  end

  private

  def super_admin!
    return if current_user&.super_admin?

    redirect_to root_path, alert: "You are not allowed to do that."
  end
end