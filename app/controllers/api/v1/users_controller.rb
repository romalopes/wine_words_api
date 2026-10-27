class Api::V1::UsersController < ApplicationController
  audit_actions create: "account_created", assign_roles: "role_change", assign_subscription: "subscription_change",
                update_account: "account_update", invitation_email: "invitation_email_updated"

  def log_description
    if action_name == "create"
      %(Created unclaimed account for "#{@target_user&.display_name}")
    elsif action_name == "assign_roles"
      %(Changed roles for user "#{@target_user&.display_name}"#{audit_roles_diff})
    elsif action_name == "update_account"
      %(Updated account settings for user "#{@target_user&.display_name}")
    else
      target = @assigned_subscription ? %( to "#{@assigned_subscription.name}") : ""
      %(Changed subscription for user "#{@target_user&.display_name}"#{target})
    end
  end

  # POST /api/v1/users
  # Creates a passwordless, unclaimed account. Admins may assign any non-admin
  # role; Editors are restricted to Reader/Reviewer. Producer memberships are
  # created in the same transaction and always attribute the authenticated actor.
  def create
    return head(:forbidden) unless real_current_user&.catalogue_manager?

    result = PrivilegedAccountCreation.call(actor: real_current_user, attributes: create_user_params.to_h)
    @target_user = result.user

    if result.success?
      render json: user_detail_json(result.user), status: :created
    else
      render json: { errors: result.errors }, status: result.forbidden? ? :forbidden : :unprocessable_entity
    end
  end

  def invitation_email
    return head(:forbidden) unless real_current_user&.catalogue_manager?

    @target_user = User.find(params[:id])
    return render json: { error: "Only unclaimed accounts can change invitation email" }, status: :unprocessable_entity unless @target_user.unclaimed?
    return head(:forbidden) if !real_current_user.admin? && @target_user.roles.where(name: %w[Admin Editor]).exists?

    @target_user.update!(email: params.require(:user).permit(:email)[:email])
    render json: user_detail_json(@target_user.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
  end

  def log_objects
    [ current_user, @target_user, @target_user&.account, @assigned_subscription ].compact
  end

  def me
    current_sub = current_user.user_subscriptions.current.first
    pending_change = current_user.subscription_changes.most_recent_for(current_user)
    render json: {
      user: {
        id: current_user.id,
        email: current_user.email,
        display_name: current_user.display_name,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        roles: current_user.role_names,
        analytics_opt_out: current_user.analytics_opt_out,
        subscription: current_user.subscription ? { id: current_user.subscription.id, name: current_user.subscription.name } : nil,
        billing_provider: current_sub&.billing_provider,
        can_manage_billing: Billing.configured?,
        subscription_status: current_sub&.status,
        # Scheduled/pending plan change so the UI can show the downgrade banner.
        subscription_change: pending_change && {
          id: pending_change.id,
          change_type: pending_change.change_type,
          status: pending_change.status,
          effective_at: pending_change.effective_at,
          to_subscription: pending_change.to_subscription && {
            id: pending_change.to_subscription.id,
            name: pending_change.to_subscription.name,
            slug: pending_change.to_subscription.slug
          }
        }
      }
    }
  end

  # GET /api/v1/users/search?q=name-or-email&page=N
  #
  # Search by account name OR email. With ?page=N the response is the standard
  # pagination envelope (20 per page by default, see Api::Paginatable); without
  # a page param the legacy plain-array response (limit 20) is kept for
  # compatibility.
  def search
    return head(:forbidden) unless real_current_user&.catalogue_manager?

    query = params[:q].to_s.strip
    users = User.search_by_name_or_email(query)

    rendered = render_paginated(users) { |page_items| page_items.map { |u| user_json(u) } }
    render json: users.limit(20).map { |u| user_json(u) } unless rendered
  end

  # GET /api/v1/roles - the full role list (id + human name), for role pickers.
  def roles
    return head(:forbidden) unless real_current_user&.catalogue_manager?
    render json: Role.order(:id).map { |r| { id: r.id, name: Role.names[r.name.to_s] || r.name.to_s } }
  end

  # GET /api/v1/users/:id - detailed user info including producer memberships
  def show
    return head(:forbidden) unless real_current_user&.catalogue_manager?

    user = User.includes(:roles, :subscription, :producer_memberships, producers: :country).find(params[:id])
    render json: user_detail_json(user)
  end

  # PATCH /api/v1/users/:id/roles   body: { role_ids: [1,3] }
  # Admin only.
  def assign_roles
    return head(:forbidden) unless real_current_user&.admin?

    user = User.find(params[:id])
    @target_user = user
    old_role_names = user.role_names
    role_ids = Array(params[:role_ids]).compact.map(&:to_i)

    # Guardrail: an admin cannot revoke their own Admin role (no self-lockout —
    # an admin dropping Admin could leave the system without any admin).
    admin_role_id = Role.find_by(name: Role.names[:admin])&.id
    if user.id == real_current_user.id && !role_ids.include?(admin_role_id)
      return render json: { error: "You cannot revoke your own Admin role." },
                    status: :unprocessable_entity
    end

    user.user_roles.destroy_all
    role_ids.each { |rid| user.user_roles.create!(role_id: rid) }
    @role_change_from = old_role_names
    @role_change_to = user.reload.role_names
    render json: user_json(user.reload)
  end

  # PATCH /api/v1/users/:id/assign_subscription  body: { subscription_id: 2 }
  # Admin only. Applies the subscription and swaps the base access role
  # (Guest <-> Reader) while preserving privileged roles and history.
  # Rejects downgrades (assigning a lower-priced plan) with a 422 error.
  def assign_subscription
    return head(:forbidden) unless real_current_user&.admin?

    user = User.find(params[:id])
    @target_user = user
    subscription = Subscription.find(params[:subscription_id])
    @assigned_subscription = subscription

    user.apply_subscription!(subscription)
    render json: user_json(user.reload)
  rescue Billing::Error => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # PATCH /api/v1/users/:id/account — admin update of another user's personal
  # information and address. Passwords and authentication identities are kept
  # out of this endpoint intentionally.
  # DELETE /api/v1/users/:id — soft delete (admin only)
  def soft_delete
    return head(:forbidden) unless real_current_user&.admin?

    @target_user = User.find(params[:id])

    result = AccountDeletionService.soft_delete(@target_user, actor: real_current_user)

    if result.success?
      render json: { status: "soft_deleted", user_id: @target_user.id }, status: :ok
    else
      render json: { error: result.error || "soft_delete_failed" }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/users/:id/hard — hard delete (admin only, behind feature flag)
  def hard_delete
    return head(:forbidden) unless real_current_user&.admin?

    unless AppSetting.hard_delete_enabled?
      return render json: { error: "hard_delete_disabled" }, status: :forbidden
    end

    @target_user = User.find(params[:id])

    result = AccountDeletionService.hard_delete(@target_user, actor: real_current_user)

    if result.success?
      render json: { status: "hard_deleted", user_id: @target_user.id }, status: :ok
    else
      status =
        case result.error
        when "blocked" then :conflict
        when "already_deleted" then :gone
        else :unprocessable_entity
        end
      render json: { error: result.error, blocking_reasons: result.blocking_reasons }, status: status
    end
  end

  # POST /api/v1/users/:id/reactivate — reactivate soft‑deleted user (admin only)
  def reactivate
    return head(:forbidden) unless real_current_user&.admin?

    @target_user = User.find(params[:id])

    result = AccountDeletionService.reactivate(@target_user, actor: real_current_user)

    if result.success?
      render json: { status: "reactivated", user_id: @target_user.id }, status: :ok
    else
      render json: { error: result.error || "reactivate_failed" }, status: :unprocessable_entity
    end
  end

  def update_account
    return head(:forbidden) unless real_current_user&.admin?

    @target_user = User.find(params[:id])
    account = Account.build_default(@target_user)

    Account.transaction do
      account.assign_attributes(account_params)
      account.save!(context: :profile)
    end

    render json: account_json(account.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  private

  def create_user_params
    params.require(:user).permit(
      :first_name, :last_name, :email,
      role_ids: [],
      producer_memberships: [ :producer_id, :membership_type ]
    )
  end

  def audit_roles_diff
    from = Array(@role_change_from).join(", ")
    to = Array(@role_change_to).join(", ")
    return "" if from.blank? || from == to

    " (from #{from} to #{to})"
  end

  def account_params
    permitted = params.permit(
      :first_name, :last_name, :phone, :date_of_birth,
      address: [ :street_address, :city, :state, :postal_code, :country_id ]
    ).to_h
    permitted[:account_address_attributes] = permitted.delete(:address) if permitted[:address]
    permitted
  end

  def account_json(account)
    address = account.account_address && {
      street_address: account.account_address.street_address,
      city: account.account_address.city,
      state: account.account_address.state,
      postal_code: account.account_address.postal_code,
      country_id: account.account_address.country_id
    }

    {
      first_name: account.first_name,
      last_name: account.last_name,
      phone: account.phone,
      date_of_birth: account.date_of_birth,
      address: address
    }
  end

  def user_json(user)
    {
      id: user.id,
      email: user.email,
      display_name: user.display_name,
      first_name: user.first_name,
      last_name: user.last_name,
      role_ids: user.role_ids,
      roles: user.role_names,
      subscription: user.subscription ? { id: user.subscription.id, name: user.subscription.name } : nil,
      account_status: user.account_status
    }
  end

  def user_detail_json(user)
    detail = user_json(user).merge(
      analytics_opt_out: user.analytics_opt_out,
      deleted_at: user.deleted_at,
      invitation_summary: invitation_summary_json(user),
      producer_memberships: user.producer_memberships.map do |pm|
        {
          id: pm.id,
          membership_type: pm.membership_type,
          can_edit: pm.can_edit_producer?,
          producer: {
            id: pm.producer.id,
            name: pm.producer.name,
            slug: pm.producer.slug,
            country: pm.producer.country&.name
          },
          created_by: pm.created_by ? { id: pm.created_by.id, display_name: pm.created_by.display_name } : nil,
          created_at: pm.created_at,
          updated_at: pm.updated_at
        }
      end
    )
    detail[:account] = account_json(Account.build_default(user)) if real_current_user&.admin?
    detail
  end

  def invitation_summary_json(user)
    latest = user.account_invitations.order(created_at: :desc).first
    return { count: 0, latest: nil } unless latest

    { count: user.account_invitations.size, latest: invitation_json(latest) }
  end

  def invitation_json(invitation)
    {
      id: invitation.id,
      email: invitation.email,
      status: invitation.status,
      usable: invitation.usable?,
      expires_at: invitation.expires_at,
      sent_at: invitation.sent_at,
      accepted_at: invitation.accepted_at,
      revoked_at: invitation.revoked_at,
      delivery_status: invitation.delivery_status,
      delivery_error_code: invitation.delivery_error_code,
      created_at: invitation.created_at
    }
  end
end
