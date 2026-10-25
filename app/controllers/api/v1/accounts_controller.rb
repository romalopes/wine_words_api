class Api::V1::AccountsController < ApplicationController
  audit_actions update: "account_update", update_password: "password_change"

  def log_description
    if action_name == "update_password"
      "Changed password for user \"#{current_user.display_name}\""
    else
      "Updated account settings for user \"#{current_user.display_name}\""
    end
  end

  def log_objects
    [current_user, current_user.account].compact
  end

  before_action :authenticate_user!

  # GET /api/v1/account — current user's account with nested address.
  # Every user has a persisted account.
  def show
    render json: account_json
  end

  # PATCH /api/v1/account — update personal info and address.
  def update
    account = Account.build_default(current_user)

    User.transaction do
      account.assign_attributes(account_params)
      account.save!(context: :profile)
    end

    render json: account_json(account.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { errors: e.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  # PATCH /api/v1/account/password — change password, verifying the current one.
  def update_password
    unless current_user.valid_password?(params[:current_password])
      return render json: { errors: { current_password: ["is incorrect"] } }, status: :unprocessable_entity
    end

    if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      render json: { status: "password_updated" }
    else
      render json: { errors: current_user.errors.to_hash(true) }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/account/analytics_opt_out — toggle content-view tracking.
  # Body: { analytics_opt_out: true|false }.
  def update_analytics_opt_out
    value = params[:analytics_opt_out]
    unless [ true, false ].include?(value)
      return render json: { errors: { analytics_opt_out: ["must be true or false"] } },
                    status: :unprocessable_entity
    end

    current_user.update!(analytics_opt_out: value)
    render json: { analytics_opt_out: current_user.analytics_opt_out }
  end

  # GET /api/v1/account/producers — current user's linked producers, with the
  # membership type and the server-derived edit capability (issue #191).
  def my_producers
    memberships = current_user.producer_memberships
                              .includes(producer: :country)
                              .order(:id)
    render json: memberships.map { |membership| producer_summary_json(membership) }
  end

  # GET /api/v1/account/notification_preferences — how the user receives
  # follow-based notifications (issue #192 phase 8). Always returns a row
  # (created lazily with the defaults).
  def show_notification_preferences
    render json: NotificationPreference.for(current_user).as_json
  end

  # PATCH /api/v1/account/notification_preferences
  # Body: { follow_in_app: true|false, follow_email: true|false,
  #         digest_cadence: "none"|"daily"|"weekly" }
  def update_notification_preferences
    preference = NotificationPreference.for(current_user)

    if preference.update(preference_params)
      render json: preference.as_json
    else
      render json: { errors: preference.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def preference_params
    permitted = params.permit(:follow_in_app, :follow_email, :digest_cadence).to_h
    permitted[:follow_in_app] = ActiveModel::Type::Boolean.new.cast(permitted[:follow_in_app]) if permitted.key?(:follow_in_app)
    permitted[:follow_email] = ActiveModel::Type::Boolean.new.cast(permitted[:follow_email]) if permitted.key?(:follow_email)
    permitted
  end

  def account_params
    permitted = params.permit(
      :first_name, :last_name, :phone, :date_of_birth,
      address: [:street_address, :city, :state, :postal_code, :country_id]
    ).to_h
    permitted[:account_address_attributes] = permitted.delete(:address) if permitted[:address]
    permitted
  end

  def account_json(account = Account.build_default(current_user))
    address =
      if account.persisted? && account.account_address
        {
          street_address: account.account_address.street_address,
          city: account.account_address.city,
          state: account.account_address.state,
          postal_code: account.account_address.postal_code,
          country_id: account.account_address.country_id
        }
      end

    {
      first_name: account.first_name,
      last_name: account.last_name,
      phone: account.phone,
      date_of_birth: account.date_of_birth,
      address: address
    }
  end

  def producer_summary_json(membership)
    producer = membership.producer
    {
      id: producer.id,
      name: producer.name,
      slug: producer.slug,
      country: producer.country&.name,
      email: producer.email,
      producer_type: producer.producer_type,
      founded_year: producer.founded_year,
      membership_id: membership.id,
      membership_type: membership.membership_type,
      # Owners/Managers may edit; Contributors may only view, even though
      # catalogue staff keep their global rights.
      can_edit: membership.can_edit_producer? || current_user.wine_manager?
    }
  end
end
