# Trade Management for Editors/Admins (IDENTITY_206 Phases 7/10/12/13).
#
#   GET   /api/v1/admin/trade/packages          queue (filterable)
#   GET   /api/v1/admin/trade/packages/:id      assessment detail
#   PATCH /api/v1/admin/trade/packages/:id/assess       per-wine decisions
#   POST  /api/v1/admin/trade/packages/:id/match_producer  link only
#   POST  /api/v1/admin/trade/packages/:id/internal_note   staff-only note
#   POST  /api/v1/admin/trade/packages/:id/release_shipping payment gate
#   PATCH /api/v1/admin/trade/packages/:id/items/:item_id/receipt
#   POST  /api/v1/admin/trade/packages/:id/items/:item_id/match_catalogue
#   POST  /api/v1/admin/trade/packages/:id/items/:item_id/assign_reviewer
#
# Authorization: Editor/Admin only (catalogue_manager?). Producer membership is
# NEVER granted by any action here, and internal notes ride the existing
# WinePackageEvent visibility boundary.
class Api::V1::Admin::Trade::PackagesController < ApplicationController
  before_action :set_package,
                only: %i[show assess match_producer internal_note release_shipping receipt match_catalogue assign_reviewer]
  before_action :ensure_trade_manager!

  rescue_from Trade::Error, with: :render_trade_error
  rescue_from WinePackage::InvalidTransition, with: :render_invalid_transition

  # GET /api/v1/admin/trade/packages?status=&q=
  def index
    scope = WinePackage.trade_submissions.includes(:wine_package_items).order(created_at: :desc)
    scope = scope.where(status: params[:status]) if params[:status].present?
    if params[:q].present?
      q = "%#{params[:q].downcase}%"
      scope = scope.where(
        "LOWER(contact_snapshot->>'company_name') LIKE :q OR LOWER(contact_snapshot->>'email') LIKE :q",
        q: q
      )
    end
    packages = scope.order(created_at: :asc).limit(limit).offset(offset)
    render json: {
      packages: packages.map { |p| TradePackageSerializer.new(p, viewer: :staff).as_json },
      meta: { limit: limit, offset: offset, total_count: scope.count }
    }
  end

  # GET /api/v1/admin/trade/packages/:id
  def show
    render json: TradePackageSerializer.new(@package, viewer: :staff).as_json
  end

  # PATCH .../assess
  def assess
    Trade::Assessment.call(@package, editor: current_user,
                                  decisions: params[:decisions] || {},
                                  reason: params[:reason])
    render json: TradePackageSerializer.new(@package.reload, viewer: :staff).as_json
  end

  # POST .../match_producer { producer_id } — links, never grants membership.
  def match_producer
    producer = Producer.find_by(id: params[:producer_id])
    return render json: { error: "unknown producer" }, status: :not_found if producer.nil?

    ActiveRecord::Base.transaction do
      @package.update!(producer: producer)
      @package.wine_package_events.create!(
        event_type: "producer_matched",
        actor: current_user,
        visibility: "internal",
        occurred_at: Time.current,
        metadata: { producer_id: producer.id, producer_name: producer.name }
      )
    end
    render json: TradePackageSerializer.new(@package.reload, viewer: :staff).as_json
  end

  # POST .../internal_note { body } — audited, staff-only.
  def internal_note
    event = @package.wine_package_events.create!(
      event_type: "note_added",
      actor: current_user,
      visibility: "internal",
      occurred_at: Time.current,
      description: params[:body].to_s.presence
    )
    render json: { id: event.id, body: event.description }, status: :created
  end

  # POST .../release_shipping { override: false, reason: nil }
  def release_shipping
    Trade::Shipping::Release.call(@package, by: current_user,
                                         override: ActiveModel::Type::Boolean.new.cast(params[:override]),
                                         reason: params[:reason])
    render json: TradePackageSerializer.new(@package.reload, viewer: :staff).as_json
  end

  # PATCH /api/v1/admin/trade/packages/:id/items/:item_id/receipt
  def receipt
    item = @package.items.find(params[:item_id])
    Trade::Receipts::Record.call(item, by: current_user,
                                       condition: params[:condition] || "good",
                                       notes: params[:notes])
    render json: TradePackageSerializer.new(@package.reload, viewer: :staff).as_json
  end

  # POST .../items/:item_id/match_catalogue { wine_id, vintage_id? }
  def match_catalogue
    item = @package.items.find(params[:item_id])
    wine = Wine.find_by(id: params[:wine_id])
    return render json: { error: "unknown wine" }, status: :not_found if wine.nil?

    vintage = wine.vintages.find_by(id: params[:vintage_id]) if params[:vintage_id].present?
    ActiveRecord::Base.transaction do
      item.update!(catalogue_wine: wine, vintage: vintage, item_status: "matched")
      @package.wine_package_events.create!(
        event_type: "catalogue_matched",
        actor: current_user,
        visibility: "internal",
        occurred_at: Time.current,
        metadata: { wine_package_item_id: item.id, wine_id: wine.id, vintage_id: vintage&.id }
      )
    end
    render json: TradePackageSerializer.new(@package.reload, viewer: :staff).as_json
  end

  # POST .../items/:item_id/assign_reviewer { reviewer_id }
  def assign_reviewer
    item = @package.items.find(params[:item_id])
    reviewer = User.find_by(id: params[:reviewer_id])
    return render json: { error: "unknown reviewer" }, status: :not_found if reviewer.nil?

    ActiveRecord::Base.transaction do
      item.update!(review_requested: true)
      @package.update!(reviewer: reviewer) if @package.reviewer.blank?
      @package.wine_package_events.create!(
        event_type: "review_assigned",
        actor: current_user,
        visibility: "internal",
        occurred_at: Time.current,
        metadata: { wine_package_item_id: item.id, reviewer_id: reviewer.id }
      )
    end
    render json: TradePackageSerializer.new(@package.reload, viewer: :staff).as_json
  end

  private

  def ensure_trade_manager!
    return if current_user&.catalogue_manager?
    return if current_user && @package && @package.submitter_id == current_user.id

    render json: { error: "forbidden" }, status: :forbidden
  end

  def set_package
    @package = WinePackage.trade_submissions.find_by(id: params[:id] || params[:package_id])
    return render json: { error: "not found" }, status: :not_found if @package.nil?
  end

  def limit
    (params[:per_page] || 25).to_i.clamp(1, 100)
  end

  def offset
    (params[:page] || 1).to_i.pred * limit
  end

  def render_trade_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def render_invalid_transition(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end
end