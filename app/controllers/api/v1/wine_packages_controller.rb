# Wine packages: the reviewing workflow's main resource.
#
# The controller is intentionally thin — every state change goes through the
# WinePackages::* services or the model's transition guard, so the same rules
# apply here, in the console and in the future producer portal. Workflow actions
# are separate routes (never a free-form `status` write) so an illegal move is
# rejected rather than silently stored.
# Issue #199 producer management: an ordinary signed-in user who is an active
# owner/manager member of a producer may
#   * open a producer-managed draft (source producer_request) for THEIR producer
#     and add wine lines — including wines not yet in the catalogue;
#   * edit their draft fields, submit the request and withdraw it while it is
#     still pending;
#   * read the producer-safe package view, timeline and progress.
# Editorial workflow actions (accept/reject/arrival/completion/destroy) stay
# editorial-only, and producers never see editorial-only fields.
class Api::V1::WinePackagesController < ApplicationController
  include WinePackageAuthorizable

  # The statuses a package may be CREATED in. Everything else is reached
  # through the workflow actions below.
  ENTRY_STATUSES = %w[draft announced requested arrived].freeze

  # Workflow actions guarded by ensure_package_manageable! — editorial-only,
  # a producer member can never drive the editorial workflow (§2).
  MANAGEABLE_ACTIONS = %i[
    destroy mark_arrived mark_in_transit start_reviewing mark_completed reopen cancel
    accept reject
  ].freeze

  audit_actions :create, :update, :destroy,
                submit: "wine_package.submitted",
                withdraw: "wine_package.withdrawn",
                restore_draft: "wine_package.restored_to_draft",
                mark_arrived: "wine_package.arrived",
                mark_in_transit: "wine_package.in_transit",
                start_reviewing: "wine_package.reviewing",
                mark_completed: "wine_package.completed",
                reopen: "wine_package.reopened",
                cancel: "wine_package.cancelled",
                accept: "wine_package.accepted",
                reject: "wine_package.rejected"

  before_action :set_package,
                only: [ :show, :update, :submit, :withdraw, :restore_draft, :timeline, :progress ] +
                      MANAGEABLE_ACTIONS
  before_action :ensure_package_visible!, only: [ :show, :timeline, :progress ]
  before_action :ensure_package_editable!, only: %i[update submit]
  before_action :ensure_package_withdrawable!, only: [ :withdraw ]
  before_action :ensure_package_restorable!, only: [ :restore_draft ]
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
               .includes(:producer, { reviewer: :account }, :wine_package_items)
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
    render json: WinePackageSerializer.new(@package, request.base_url, viewer: current_user).as_json
  end

  # POST /api/v1/wine_packages
  #
  # `status` selects the entry point: "draft" (default), "announced" (an
  # expected package), "requested" (a producer asked for a review) or "arrived"
  # (a package received today — the review clock starts and the 15/5/0-day
  # reminders are scheduled).
  #
  # A producer member (issue #199) always creates a plain draft with source
  # producer_request and no reviewer assigned: the request is submitted
  # explicitly via POST /:id/submit and the editorial team picks the reviewer
  # when the request is accepted. Wine lines (catalogue vintages or proposed
  # wines) may be supplied inline through wine_package_items_attributes.
  def create
    producer_view = producer_creator?

    unless producer_view || ENTRY_STATUSES.include?(entry_status)
      return render json: {
        errors: [ "status must be one of: #{ENTRY_STATUSES.join(', ')}" ]
      }, status: :unprocessable_entity
    end

    package = WinePackage.new(producer_view ? producer_create_params : package_params)
    # New packages always start at draft and are moved by the workflow, so an
    # arbitrary status can never be written straight into the column.
    package.status = "draft"
    package.created_by = current_user
    if producer_view
      package.source = "producer_request"
      package.requested_by = current_user
      # A producer request starts unassigned — editorial picks the reviewer.
    else
      package.reviewer ||= current_user
    end
    @package = package

    authorize package, :create?
    package.save!
    apply_entry_status!(package) unless producer_view

    render json: WinePackageSerializer.new(package.reload, request.base_url, viewer: current_user).as_json,
           status: :created
  end

  # PATCH /api/v1/wine_packages/:id
  #
  # Status and source are workflow-owned and therefore not assignable here.
  # A producer member may only edit their own draft's producer-editable fields;
  # editors/admins/reviewers keep the existing full field set.
  def update
    @package.update!(package_producer_member? ? producer_update_params : update_params)
    render json: WinePackageSerializer.new(@package, request.base_url, viewer: current_user).as_json
  end

  def destroy
    @package.destroy
    head :no_content
  end

  # --- Producer request wizard (issue #199) --------------------------------

  # POST /api/v1/wine_packages/:id/submit
  #
  # Submits a producer-managed draft as a review request (draft -> requested).
  # Editors are notified; the package's activity timeline records the step.
  def submit
    WinePackages::SubmitRequest.call(
      @package,
      user: current_user,
      at: parsed_time(:submitted_at) || Time.current
    )
    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  # POST /api/v1/wine_packages/:id/withdraw
  #
  # Withdraws a pending (requested) producer request — the package is cancelled
  # through the ordinary workflow, editors are notified and the timeline
  # records the withdrawal.
  def withdraw
    WinePackages::WithdrawRequest.call(@package, user: current_user)
    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  def restore_draft
    @package.restore_draft!(actor: current_user)
    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  # GET /api/v1/wine_packages/:id/timeline
  #
  # Merged, viewer-scoped activity timeline: application milestones (submitted,
  # accepted, rejected, arrival confirmed, review published ...) plus the raw
  # carrier tracking events. Producer viewers never see editorial-only entries.
  def timeline
    render json: { events: WinePackages::Timeline.events(@package, viewer: current_user) }
  end

  # GET /api/v1/wine_packages/:id/progress
  #
  # Safe aggregate editorial progress for the producer dashboard: overall
  # status, per-item review statuses and the published/total counts. Never
  # ships draft review content, scores or internal notes.
  def progress
    render json: {
      id: @package.id,
      status: @package.status,
      review_progress: @package.review_progress,
      items: @package.wine_package_items.map { |item|
        {
          id: item.id,
          label: item.label,
          review_status: item.review&.status,
          reviewed: item.reviewed?,
          pending_review: item.pending_review?
        }
      }
    }
  end

  # --- Workflow actions ---------------------------------------------------

  # Arrival starts the review clock (arrived + 1 calendar month unless a
  # deadline was supplied) and schedules the reminders. If every requested item
  # already has a published review, the package completes immediately.
  def mark_arrived
    WinePackages::MarkArrived.call(
      @package,
      at: parsed_time(:arrived_at) || Time.current,
      deadline: parsed_date(:review_deadline),
      actor: current_user
    )
    WinePackages::CheckCompletion.call(@package)

    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  def mark_in_transit
    @package.mark_in_transit!(actor: current_user)
    render json: WinePackageSerializer.new(@package, request.base_url, viewer: current_user).as_json
  end

  def start_reviewing
    @package.start_reviewing!(actor: current_user)
    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  def mark_completed
    WinePackages::MarkCompleted.call(@package, at: parsed_time(:reviewed_at) || Time.current, actor: current_user)
    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  def reopen
    @package.reopen!(actor: current_user)
    render json: WinePackageSerializer.new(@package, request.base_url, viewer: current_user).as_json
  end

  def cancel
    @package.cancel!(actor: current_user)
    render json: WinePackageSerializer.new(@package, request.base_url, viewer: current_user).as_json
  end

  def accept
    reviewer = acceptance_reviewer
    return unless reviewer

    @package.reviewer = reviewer
    @package.accept!(by: current_user)
    WinePackages::Notifications::Lifecycle.deliver!(@package, event: "accepted", actor: current_user)
    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  def reject
    @package.reject!(by: current_user, reason: params[:rejection_reason])
    WinePackages::Notifications::Lifecycle.deliver!(@package, event: "rejected", actor: current_user)
    render json: WinePackageSerializer.new(@package.reload, request.base_url, viewer: current_user).as_json
  end

  private

  def ensure_package_restorable!
    authorize @package, :restore_draft?
  end

  def acceptance_reviewer
    reviewer_id = raw_param(:reviewer_id).presence
    reviewer = reviewer_id.blank? ? current_user : User.find(reviewer_id)
    return reviewer if reviewer.active? && reviewer.wine_manager?

    render json: { error: "Reviewer must be an active Admin, Editor, or Reviewer" },
           status: :unprocessable_entity
    nil
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Reviewer not found" }, status: :unprocessable_entity
    nil
  end

  def serialize_packages(packages)
    packages.map { |package| WinePackageListSerializer.new(package, request.base_url, viewer: current_user).as_json }
  end

  # True when the caller is NOT a wine manager but IS an active owner/manager
  # member of the producer they are creating a package for (issue #199). Such a
  # caller opens a producer-managed draft: source is forced to producer_request
  # and the requester is recorded; no reviewer may be self-assigned.
  def producer_creator?
    return false if current_user.nil? || current_user.wine_manager?

    producer_id = params.dig(:wine_package, :producer_id).presence
    return false unless producer_id

    ProducerMembership.where(
      user_id: current_user.id,
      producer_id: producer_id,
      membership_type: ProducerMembership::EDITABLE_TYPES
    ).exists?
  end

  def package_producer_member?
    return false unless current_user

    WinePackagePolicy.new(current_user, @package).producer_member?
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
      package.transition_to!("announced", actor: current_user)
    when "requested"
      package.request!(actor: current_user)
    when "arrived"
      WinePackages::MarkArrived.call(
        package,
        at: package.arrived_at || Time.current,
        deadline: package.review_deadline,
        actor: current_user
      )
    end
  end

  def set_package
    @package = WinePackage.includes(:producer, { reviewer: :account }, wine_package_items: :review)
                         .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine package not found" }, status: :not_found
  end

  # Same visibility as #index (content managers, the reviewer, the recorder).
  # A 404 rather than a 403 so the endpoint never reveals that a package exists.
  def ensure_package_visible!
    authorize @package, :show?
  rescue Pundit::NotAuthorizedError
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

  # Producer-managed creation (issue #199): editorial-only fields (reviewer,
  # notes, tracking snapshot, source, arrival data) are never assignable from
  # the producer side, and wine lines may only propose catalogue vintages or
  # name wines that are not registered yet.
  def producer_create_params
    params.require(:wine_package).permit(
      :producer_id, :expected_at, :producer_reference, :producer_notes,
      :shipping_notes,
      wine_package_items_attributes: [
        :vintage_id, :proposed_wine_name, :proposed_vintage_year,
        :quantity, :review_requested, :condition, :notes
      ]
    )
  end

  # Producer-editable fields on an existing package (drafts only — the policy
  # enforces the state). `notes` stays editorial-only.
  def producer_update_params
    params.require(:wine_package).permit(
      :expected_at, :producer_reference, :producer_notes, :shipping_notes
    )
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
