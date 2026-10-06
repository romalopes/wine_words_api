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

  private

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
end
