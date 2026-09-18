# Wine packages: the reviewing workflow's main resource.
#
# The controller is intentionally thin — every state change goes through the
# WinePackages::* services or the model's transition guard, so the same rules
# apply here, in the console and in the future producer portal. Workflow actions
# are separate routes (never a free-form `status` write) so an illegal move is
# rejected rather than silently stored.
class Api::V1::WinePackagesController < ApplicationController
  include WinePackageAuthorizable

  # The statuses a package may be CREATED in. Everything else is reached
  # through the workflow actions below.
  ENTRY_STATUSES = %w[draft announced requested arrived].freeze

  MANAGEABLE_ACTIONS = %i[
    update destroy mark_arrived mark_in_transit mark_completed reopen cancel
    accept reject
  ].freeze

  audit_actions :create, :update, :destroy,
                mark_arrived: "wine_package.arrived",
                mark_in_transit: "wine_package.in_transit",
                mark_completed: "wine_package.completed",
                reopen: "wine_package.reopened",
                cancel: "wine_package.cancelled",
                accept: "wine_package.accepted",
                reject: "wine_package.rejected"

  before_action :ensure_package_creator!, only: [ :create ]
  before_action :set_package, only: [ :show ] + MANAGEABLE_ACTIONS
  before_action :ensure_package_visible!, only: [ :show ]
  before_action :ensure_package_manageable!, only: MANAGEABLE_ACTIONS

  rescue_from WinePackage::InvalidTransition, with: :render_invalid_transition
  rescue_from WinePackages::Error, with: :render_workflow_error
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  def log_description
    "#{audit_verb} wine package ##{@package&.id} for \"#{@package&.producer&.name}\""
  end

  def log_objects
    [ @package, @package&.producer ].compact
  end

  # GET /api/v1/wine_packages
  def index
    packages = packages_scope
               .includes(:producer, :reviewer, :wine_package_items)
               .by_recency

    packages = packages.where(status: params[:status]) if params[:status].present?
    packages = packages.where(source: params[:source]) if params[:source].present?
    packages = packages.where(producer_id: params[:producer_id]) if params[:producer_id].present?
    packages = packages.where(reviewer_id: params[:reviewer_id]) if params[:reviewer_id].present?
    packages = packages.overdue if params[:overdue] == "true"
    if params[:due_within_days].present?
      packages = packages.where(review_deadline: ..Date.current + params[:due_within_days].to_i)
    end
    if params[:query].present?
      q = "%#{params[:query].strip}%"
      packages = packages.joins(:producer).where(
        "producers.name ILIKE :q OR wine_packages.notes ILIKE :q " \
        "OR wine_packages.tracking_number ILIKE :q",
        q: q
      )
    end

    return if render_paginated(packages) { |items| serialize_packages(items) }

    render json: serialize_packages(packages)
  end

  # GET /api/v1/wine_packages/:id
  def show
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  # POST /api/v1/wine_packages
  #
  # `status` selects the entry point: "draft" (default), "announced" (an
  # expected package), "requested" (a producer asked for a review) or "arrived"
  # (a package received today — the review clock starts and the 15/5/0-day
  # reminders are scheduled).
  def create
    unless ENTRY_STATUSES.include?(entry_status)
      return render json: {
        errors: [ "status must be one of: #{ENTRY_STATUSES.join(', ')}" ]
      }, status: :unprocessable_entity
    end

    package = WinePackage.new(package_params)
    # New packages always start at draft and are moved by the workflow, so an
    # arbitrary status can never be written straight into the column.
    package.status = "draft"
    package.created_by = current_user
    package.reviewer ||= current_user
    @package = package

    package.save!
    apply_entry_status!(package)

    render json: WinePackageSerializer.new(package.reload, request.base_url).as_json,
           status: :created
  end

  # PATCH /api/v1/wine_packages/:id
  #
  # Status and source are workflow-owned and therefore not assignable here (see
  # update_params).
  def update
    @package.update!(update_params)
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  def destroy
    @package.destroy
    head :no_content
  end

  # --- Workflow actions ---------------------------------------------------

  # Arrival starts the review clock (arrived + 1 calendar month unless a
  # deadline was supplied) and schedules the reminders. If every requested item
  # already has a published review, the package completes immediately.
  def mark_arrived
    WinePackages::MarkArrived.call(
      @package,
      at: parsed_time(:arrived_at) || Time.current,
      deadline: parsed_date(:review_deadline)
    )
    WinePackages::CheckCompletion.call(@package)

    render json: WinePackageSerializer.new(@package.reload, request.base_url).as_json
  end

  def mark_in_transit
    @package.mark_in_transit!
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  def mark_completed
    WinePackages::MarkCompleted.call(@package, at: parsed_time(:reviewed_at) || Time.current)
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  def reopen
    @package.reopen!
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  def cancel
    @package.cancel!
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  def accept
    @package.accept!(by: current_user)
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  def reject
    @package.reject!(by: current_user, reason: params[:rejection_reason])
    render json: WinePackageSerializer.new(@package, request.base_url).as_json
  end

  private

  def serialize_packages(packages)
    packages.map { |package| WinePackageListSerializer.new(package, request.base_url).as_json }
  end

  # Raw `status` param (it is deliberately not permitted through package_params).
  def entry_status
    (params[:wine_package] && params[:wine_package][:status]).presence ||
      params[:status].presence || "draft"
  end

  def apply_entry_status!(package)
    case entry_status
    when "announced"
      package.announced_at ||= Time.current
      package.transition_to!("announced")
    when "requested"
      package.request!
    when "arrived"
      WinePackages::MarkArrived.call(
        package,
        at: package.arrived_at || Time.current,
        deadline: package.review_deadline
      )
    end
  end

  def set_package
    @package = WinePackage.includes(:producer, :reviewer, wine_package_items: :review)
                         .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine package not found" }, status: :not_found
  end

  # Same visibility as #index (content managers, the reviewer, the recorder).
  # A 404 rather than a 403 so the endpoint never reveals that a package exists.
  def ensure_package_visible!
    return if package_manageable?(@package) || @package.created_by_id == current_user&.id

    render json: { error: "Wine package not found" }, status: :not_found
  end

  # `source` is a business input when a package is recorded (manual /
  # unexpected / producer_request / producer_announcement). `status` is
  # deliberately absent — a new package always starts at draft and is moved by
  # the workflow actions.
  def package_params
    params.require(:wine_package).permit(
      :producer_id, :reviewer_id, :source,
      :expected_at, :announced_at, :arrived_at,
      :review_deadline, :reviewed_at, :notes,
      :tracking_carrier, :tracking_number, :tracking_url, :tracking_status,
      :tracking_status_updated_at, :estimated_delivery_at, :delivered_at
    )
  end

  # Editing a package may never rewrite its provenance — source, like status,
  # belongs to the workflow.
  def update_params
    package_params.to_h.symbolize_keys.except(:source)
  end

  # Workflow actions accept the timestamp either at the top level or nested
  # under wine_package; anything unparseable is ignored (the service then uses
  # its own default).
  def raw_param(key)
    params[key].presence || (params[:wine_package] && params[:wine_package][key]).presence
  end

  def parsed_time(key)
    value = raw_param(key)
    return nil if value.blank?

    Time.zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def parsed_date(key)
    value = raw_param(key)
    return nil if value.blank?

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def render_invalid_transition(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def render_workflow_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def render_record_invalid(error)
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end
end
