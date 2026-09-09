class Api::V1::AccountsController < ApplicationController
  before_action :authenticate_user!

  # GET /api/v1/account — current user's account with nested address.
  # Returns an unsaved default shell when the user has no account yet so the
  # settings form always has a stable shape.
  def show
    render json: account_json
  end

  # PATCH /api/v1/account — update username, personal info and address.
  # Creates the account + address rows lazily on first save.
  def update
    account = current_user.account || Account.new(user: current_user)

    User.transaction do
      current_user.update!(user_name: params[:user_name]) if params.key?(:user_name)
      account.update!(account_params)
    end

    render json: account_json(account.reload)
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    render json: { errors: errors_for(account, e) }, status: :unprocessable_entity
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

  # Aggregate validation errors from both the user (username) and the account
  # (personal info / address) so the UI can show everything at once.
  def errors_for(account, error)
    if error.is_a?(ActiveRecord::RecordNotUnique)
      { user_name: ["is already taken"] }
    elsif error.record.is_a?(User)
      current_user.errors.to_hash(true)
    else
      account.errors.to_hash(true)
    end
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
      user_name: current_user.user_name,
      first_name: account.first_name,
      last_name: account.last_name,
      phone: account.phone,
      date_of_birth: account.date_of_birth,
      address: address
    }
  end
end
