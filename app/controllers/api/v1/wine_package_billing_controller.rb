# Wine Package Billing API (IDENTITY_214).
#
# Nested under wine_packages — only accessible to users who can view/manage
# the package's billing information.
class Api::V1::WinePackageBillingController < ApplicationController
  before_action :authenticate_user!
  before_action :set_package
  before_action :authorize_billing_view, only: [:show]
  before_action :authorize_billing_manage, only: [:update]

  # GET /api/v1/wine_packages/:wine_package_id/billing
  def show
    summary = WinePackages::BillingSummary.new(@package)
    render json: summary.to_h
  end

  # PATCH /api/v1/wine_packages/:wine_package_id/billing
  # Confirms/updates the billable bottle count.
  def update
    count = billing_params[:billable_bottle_count]
    unless count.is_a?(Integer) && count.positive?
      return render json: { error: "billable_bottle_count must be a positive integer" },
                    status: :unprocessable_entity
    end

    @package.confirm_billable_quantity!(count, by: current_user)
    @package.wine_package_events.create!(
      event_type: "billable_quantity_confirmed",
      actor: current_user,
      visibility: "shared",
      occurred_at: Time.current,
      metadata: { billable_bottle_count: count }
    )

    summary = WinePackages::BillingSummary.new(@package)
    render json: summary.to_h
  end

  private

  def set_package
    @package = WinePackage.find(params[:wine_package_id])
  end

  def authorize_billing_view
    policy = WinePackagePolicy.new(current_user, @package)
    unless policy.view_billing?
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end

  def authorize_billing_manage
    policy = WinePackagePolicy.new(current_user, @package)
    unless policy.manage_billing?
      render json: { error: "Forbidden" }, status: :forbidden
    end
  end

  def billing_params
    params.permit(:billable_bottle_count)
  end
end