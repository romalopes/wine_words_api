class Api::V1::LogsController < ApplicationController
  before_action :authenticate_admin!

  # GET /api/v1/logs?lines=500
  # Returns the last `lines` lines of the current Rails environment log file.
  def index
    count = (params[:lines] || 500).to_i
    count = 500 if count <= 0
    render json: { logs: recent_log_lines(count) }
  end

  # GET /api/v1/logs/audit?page=1&per_page=20
  #     [&user_id&action&object_type&object_id&date_from&date_to&request_id&search]
  # Paginated, filterable view of the database audit trail (logs + log_objects).
  # With `page` the response uses the Api::Paginatable envelope
  # { items:, page:, per_page:, total_count:, total_pages: }; without it the
  # full scope is returned as a plain array.
  def audit_logs
    scope = audit_scope
    return if render_paginated(scope) { |items| items.map { |log| log_json(log) } }

    render json: scope.map { |log| log_json(log) }
  end

  # GET /api/v1/logs/:id
  # A single audit entry with full metadata and its associated objects,
  # including the `alive` flag (the referenced record may have been deleted).
  def show
    log = Log.includes(log_objects: :object).find(params[:id])
    render json: log_json(log, detailed: true)
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Log not found" }, status: :not_found
  end

  private

  def authenticate_admin!
    return render json: { error: "Authentication required" }, status: :unauthorized unless current_user
    return if current_user.admin?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  # Applies the query-string filters to the audit-log scope.
  def audit_scope
    scope = Log.all
    scope = scope.where(request_id: request.query_parameters[:request_id]) if request.query_parameters[:request_id].present?
    if request.query_parameters[:search].present?
      pattern = "%#{request.query_parameters[:search]}%"
      scope = scope.where(
        "description ILIKE ? OR action ILIKE ? OR path ILIKE ?",
        pattern, pattern, pattern
      )
    end
    if request.query_parameters[:object_type].present? || request.query_parameters[:object_id].present?
      conditions = {}
      conditions[:object_type] = request.query_parameters[:object_type] if request.query_parameters[:object_type].present?
      conditions[:object_id] = request.query_parameters[:object_id].to_i if request.query_parameters[:object_id].present?
      scope = scope.joins(:log_objects).where(log_objects: conditions).distinct
    end
    from = date_param(:date_from)
    scope = scope.where("logs.created_at >= ?", from.beginning_of_day) if from
    to = date_param(:date_to)
    scope = scope.where("logs.created_at <= ?", to.end_of_day) if to
    if request.query_parameters[:user_id].present?
      scope = scope.where(user_id: request.query_parameters[:user_id])
    end
    if request.query_parameters[:action].present?
      scope = scope.where("action ILIKE ?", "%#{request.query_parameters[:action]}%")
    end
    scope.order(created_at: :desc, id: :desc)
  end

  # Tolerant date parsing — invalid values are ignored rather than failing.
  def date_param(key)
    return nil if params[key].blank?

    Date.parse(params[key].to_s)
  rescue ArgumentError
    nil
  end

  # `detailed: true` switches objects to Log#object_labels, which adds the
  # `alive` flag (live lookup of the polymorphic record) for the detail view.
  def log_json(log, detailed: false)
    {
      id: log.id,
      description: log.description,
      user: log.user ? { id: log.user.id, user_name: log.user.user_name, email: log.user.email } : nil,
      action: log.action,
      method: log.method,
      path: log.path,
      status: log.status,
      request_id: log.request_id,
      ip_address: log.ip_address,
      user_agent: log.user_agent,
      created_at: log.created_at,
      objects: detailed ? log.object_labels : log.log_objects.map { |lo|
        { type: lo.object_type, id: lo.object_id, label: lo.object_label }
      }
    }
  end

  # Reads the tail of log/development.log (or log/<env>.log) without
  # loading the entire file into memory for large logs.
  def recent_log_lines(count)
    path = Rails.root.join("log", "#{Rails.env}.log")
    return [] unless File.exist?(path)

    # Use tail to read the last `count` lines efficiently.
    IO.popen(["tail", "-n", count.to_s, path.to_s], err: [:child, :out]) do |io|
      io.read
    end.lines.map(&:chomp)
  rescue StandardError
    []
  end
end
