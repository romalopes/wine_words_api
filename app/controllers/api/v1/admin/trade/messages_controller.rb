# Staff side of a trade submission conversation (IDENTITY_206 Phase 8).
#
#   GET  /api/v1/admin/trade/packages/:package_id/messages
#   POST /api/v1/admin/trade/packages/:package_id/messages
#
# Editor/Admin only. Staff see every shared message; internal notes ride the
# `note_added` events and are never sent to the submitter. Posting here creates
# a SHARED reply from the editor/admin and notifies the submitter (in-app when
# they have an account, otherwise by email to the submission's contact address).
class Api::V1::Admin::Trade::MessagesController < ApplicationController
  before_action :set_package
  before_action :ensure_trade_manager!

  # GET /api/v1/admin/trade/packages/:package_id/messages
  def index
    staff_view = current_user&.catalogue_manager?
    messages = @package.wine_package_messages.visible_to(staff_view)
                       .includes(:sender).chronological
    render json: messages.map { |m| TradeMessageSerializer.new(m, staff: staff_view).as_json }
  end

  # POST /api/v1/admin/trade/packages/:package_id/messages { body: "..." }
  def create
    message = Trade::Messages::Send.call(
      package: @package,
      sender: current_user,
      body: params[:body]
    )

    render json: TradeMessageSerializer.new(message, staff: true).as_json,
           status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence },
           status: :unprocessable_entity
  end

  private

  def ensure_trade_manager!
    return if current_user&.catalogue_manager?
    return if current_user && @package && @package.submitter_id == current_user.id

    render json: { error: "forbidden" }, status: :forbidden
  end

  def set_package
    @package = WinePackage.trade_submissions.find_by(
      id: params[:package_id] || params[:id]
    )
    return if @package

    render json: { error: "not found" }, status: :not_found
  end
end
