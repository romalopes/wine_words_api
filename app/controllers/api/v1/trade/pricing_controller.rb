# Public Wine Words review fee pricing endpoint (IDENTITY_214).
#
# GET /api/v1/trade/pricing
#
# No authentication required — the current configured fee is public information
# needed by the submission form to display the estimate before submit.
class Api::V1::Trade::PricingController < ApplicationController
  skip_before_action :authenticate_user!
  skip_before_action :enforce_email_verification!
  skip_before_action :reject_deleted_user!

  def show
    render json: {
      wine_review_fee: {
        amount: AppSetting.wine_review_fee_amount_formatted,
        currency: AppSetting.wine_review_fee_currency,
        unit: "bottle"
      }
    }
  end
end