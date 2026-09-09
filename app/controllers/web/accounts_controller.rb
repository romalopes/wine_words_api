class Web::AccountsController < Web::BaseController
  before_action :authenticate_user!

  def show
    load_account
  end

  def update
    load_account

    User.transaction do
      current_user.update!(user_name: params[:user_name]) if params[:user_name].present?
      @account.update!(account_params)
    end

    redirect_to account_path, notice: "Account updated."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    @errors = errors_for(e)
    render :show, status: :unprocessable_entity
  end

  def update_password
    unless current_user.valid_password?(params[:current_password])
      flash.now[:alert] = "Current password is incorrect."
      load_account
      return render :show, status: :unprocessable_entity
    end

    if current_user.update(password: params[:password], password_confirmation: params[:password_confirmation])
      redirect_to account_path, notice: "Password updated."
    else
      flash.now[:alert] = current_user.errors.full_messages.join(", ")
      load_account
      render :show, status: :unprocessable_entity
    end
  end

  private

  def load_account
    @account = current_user.account ||
               Account.new(user: current_user, account_address: AccountAddress.new)
    @countries = Country.order(:name)
  end

  def account_params
    permitted = params.require(:account).permit(
      :first_name, :last_name, :phone, :date_of_birth,
      account_address_attributes: [:street_address, :city, :state, :postal_code, :country_id]
    ).to_h
    if (addr = permitted[:account_address_attributes])
      addr = @account.account_address || AccountAddress.new
      permitted[:account_address_attributes] = addr.attributes
        .slice("street_address", "city", "state", "postal_code", "country_id")
        .merge(permitted[:account_address_attributes])
      permitted[:account_address_attributes][:id] = addr.id if addr.persisted?
    end
    permitted
  end

  def errors_for(error)
    if error.is_a?(ActiveRecord::RecordNotUnique)
      ["Username is already taken."]
    elsif error.record.is_a?(User)
      current_user.errors.full_messages
    else
      @account.errors.full_messages
    end
  end
end
