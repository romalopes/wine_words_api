# Trade package conversations (IDENTITY_206 Phase 8).
#
#   GET/POST /api/v1/trade/packages/:package_id/messages
#
# Access: the package owner (submitter_id == current_user) or a holder of the
# package's valid guest token (passed as the guest_token param for guest
# flows). Submitters NEVER see internal_note messages — the scope guarantees
# the confidentiality boundary regardless of serializer changes.
class Api::V1::Trade::MessagesController < ApplicationController
  # Guest-token holders may read/post without a user account.
  skip_before_action :authenticate_user!, only: %i[index create]
  skip_before_action :enforce_email_verification!, only: %i[index create]

  before_action :set_package_and_viewer

  def index
    messages = @package.wine_package_messages.visible_to(@staff)
                       .includes(:sender).chronological
    render json: messages.map { |m| TradeMessageSerializer.new(m, staff: @staff).as_json }
  end

  def create
    message = Trade::Messages::Send.call(
      package: @package,
      sender: current_user,
      body: params[:body]
    )

    render json: TradeMessageSerializer.new(message, staff: @staff).as_json, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence },
           status: :unprocessable_entity
  end

  private

  # Owner (submitter_id == current_user) OR a valid guest token. Anything else
  # is a uniform 404 so package IDs cannot be probed.
  def set_package_and_viewer
    @package = WinePackage.trade_submissions.find_by(id: params[:package_id])
    return render json: { error: "not found" }, status: :not_found if @package.nil?

    @staff = false
    return if current_user && @package.submitter_id == current_user.id
    return if params[:guest_token].present? && @package.guest_token_valid?(params[:guest_token])

    render json: { error: "not found" }, status: :not_found
  end
end
