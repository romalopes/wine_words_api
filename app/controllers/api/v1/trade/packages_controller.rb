# Trade packages for SUBMITTERS (IDENTITY_206 Phases 5/6/12).
#
# Three access paths, each with its own authorization:
#   * GET  /api/v1/trade/my-packages          — authenticated; submitter_id = me
#   * GET  /api/v1/trade/packages/:id         — authenticated; owner only
#   * GET  /api/v1/trade/guest_packages/:token — public; single-use guest token
#   * POST /api/v1/trade/guest_packages/:token/claim — authenticated; links
#                                                            submitter_id
#   * PATCH /api/v1/trade/packages/:id/shipping_address — owner, post-payment
#
# Guest tokens are hashed at rest and looked up by digest; expiry/revocation
# is checked by WinePackage#guest_token_valid?. An invalid token is reported
# as 404 (not 401/403) so token validity can never be probed for other users'
# packages.
class Api::V1::Trade::PackagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[guest_show claim]
  skip_before_action :enforce_email_verification!, only: %i[guest_show claim]

  before_action :set_owned_package, only: %i[show update_shipping_address]
  before_action :set_guest_package, only: %i[guest_show claim]

  rescue_from Trade::Error, with: :render_trade_error

  # GET /api/v1/trade/my-packages
  def index
    packages = WinePackage.submitted_by(current_user).trade_submissions
                          .includes(:wine_package_items, :wine_package_events)
                          .order(created_at: :desc)
    render json: packages.map { |p| TradePackageSerializer.new(p, viewer: :submitter).as_json }
  end

  # GET /api/v1/trade/packages/:id
  def show
    render json: TradePackageSerializer.new(@package, viewer: :submitter).as_json
  end

  # PATCH /api/v1/trade/packages/:id/shipping_address (Phase 12)
  def update_shipping_address
    unless @package.status.in?(%w[paid shipping_pending shipping_released])
      return render json: { error: "shipping details are collected after payment" },
                    status: :unprocessable_entity
    end

    @package.update!(shipping_address: shipping_address_params)
    render json: { status: "saved" }
  end

  # GET /api/v1/trade/guest_packages/:token
  def guest_show
    render json: TradePackageSerializer.new(@package, viewer: :guest).as_json
  end

  # POST /api/v1/trade/guest_packages/:token/claim
  def claim
    package = Trade::Packages::Claim.call(
      package: @package, user: current_user, guest_token: params[:token]
    )
    render json: TradePackageSerializer.new(package, viewer: :submitter).as_json
  end

  private

  def set_owned_package
    @package = WinePackage.trade_submissions.find_by(id: params[:id])
    return render_not_found if @package.nil? || @package.submitter_id != current_user.id
  end

  def set_guest_package
    digest = EmailVerificationService.digest_token(params[:token].to_s)
    @package = WinePackage.find_by(guest_token_digest: digest)
    return render_not_found if @package.nil? || !@package.guest_token_valid?(params[:token])
  end

  def shipping_address_params
    params.permit(
      :contact_name, :company, :address, :city, :region, :postal_code,
      :country, :phone, :instructions
    ).to_hash
  end

  def render_not_found
    render json: { error: "not found" }, status: :not_found
  end

  def render_trade_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end