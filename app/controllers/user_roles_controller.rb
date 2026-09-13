class UserRolesController < ActionController::Base
  layout "application"

  # Impersonation support: overrides current_user to return the effective
  # (impersonated) user, and provides real_current_user for admin gates.
  include Impersonable

  # NOTE: we intentionally do NOT include the RequireLogin concern here.
  # It registers callbacks with `only: [:new, :edit, :create, :update, :destroy]`
  # and this controller has none of those actions, which Rails 7.1+ rejects
  # ("The new action could not be found for the :require_login callback").
  before_action :set_current_user
  before_action :require_admin!

  helper_method :real_current_user, :impersonating?

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
    redirect_to user_roles_path(q: params[:q]), notice: "Roles updated for #{user.user_name || user.email}."
  end

  # POST /user_roles/impersonate/:user_id — start impersonating a user (admin only)
  def start_impersonation
    target_user = User.find_by(id: params[:user_id])
    unless target_user
      redirect_to user_roles_path, alert: "User not found."
      return
    end

    if target_user.admin?
      redirect_to user_roles_path, alert: "You cannot impersonate another admin."
      return
    end

    if session[:impersonated_user_id].present?
      redirect_to user_roles_path, alert: "You are already impersonating a user. Stop the current session first."
      return
    end

    session[:impersonated_user_id] = target_user.id
    redirect_to root_path, notice: "Now impersonating #{target_user.user_name || target_user.email}."
  end

  # DELETE /user_roles/impersonate — stop impersonating (admin only)
  def stop_impersonation
    target_name = User.find_by(id: session[:impersonated_user_id])&.user_name
    session.delete(:impersonated_user_id)
    redirect_to user_roles_path, notice: target_name ? "Stopped impersonating #{target_name}." : "Impersonation stopped."
  end

  private

  # Admin gate uses real_current_user so an admin never loses access while
  # impersonating a non-admin user.
  def require_admin!
    return if real_current_user&.admin?

    redirect_to root_path, alert: "You are not allowed to do that."
  end
end