# Contact Messages inbox for Editors and Admins (IDENTITY_209 Phase 5).
#
#   GET   /api/v1/admin/contact_messages    list (search, filters, pagination)
#   GET   /api/v1/admin/contact_messages/:id
#   PATCH /api/v1/admin/contact_messages/:id  status: read | unread | archived
#
# Authorization is ContactMessagePolicy (Admin/Editor only) and is enforced
# here regardless of what the React menu shows. The update endpoint accepts
# nothing but the status — sender identity, content and timestamps are never
# client-writable.
class Api::V1::Admin::ContactMessagesController < ApplicationController
  audit_actions update: "contact_message.update"

  before_action :set_contact_message, only: %i[show update]

  SORTABLE_COLUMNS = %w[created_at updated_at read_at archived_at subject].freeze
  SORT_DIRECTIONS = %w[asc desc].freeze

  def log_description
    "Marked contact message ##{@contact_message.id} as #{@contact_message.status}"
  end

  def log_objects
    [ @contact_message ].compact
  end

  # GET /api/v1/admin/contact_messages
  # ?status=unread&contact_type=general&search=jane&page=1&per_page=20
  # &sort=created_at&direction=desc
  def index
    authorize ContactMessage

    scope = filtered_scope
    pagination = page_params
    total_count = scope.count
    items = scope.limit(pagination[:per_page])
                 .offset((pagination[:page] - 1) * pagination[:per_page])

    render json: {
      items: items.map { |message| ContactMessageSerializer.new(message).as_json },
      page: pagination[:page],
      per_page: pagination[:per_page],
      total_count: total_count,
      total_pages: (total_count.to_f / pagination[:per_page]).ceil,
      # Archived messages never inflate the badge.
      unread_count: ContactMessage.unread.count
    }
  end

  # GET /api/v1/admin/contact_messages/:id
  def show
    authorize @contact_message

    render json: ContactMessageSerializer.new(@contact_message, include_message: true).as_json
  end

  # PATCH /api/v1/admin/contact_messages/:id { status: "read" }
  def update
    authorize @contact_message

    @contact_message.apply_status!(status_param)

    render json: ContactMessageSerializer.new(@contact_message, include_message: true).as_json
  rescue ArgumentError
    render json: { error: "Unsupported status" }, status: :unprocessable_entity
  end

  private

  def set_contact_message
    @contact_message = ContactMessage.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Contact message not found" }, status: :not_found
  end

  def status_param
    nested = params[:contact_message]
    value = nested.respond_to?(:[]) ? nested[:status] : nil
    (value.presence || params[:status].presence).to_s
  end

  def filtered_scope
    scope = ContactMessage.all

    status = params[:status].to_s
    scope = scope.where(status: status) if ContactMessage::STATUSES.include?(status)

    contact_type = params[:contact_type].to_s
    if ContactMessage::CONTACT_TYPES.include?(contact_type)
      scope = scope.where(contact_type: contact_type)
    end

    scope = scope.search(params[:search]) if params[:search].present?

    apply_sort(scope)
  end

  # Allowlisted sort column/direction only — never raw SQL from the client.
  def apply_sort(scope)
    column = params[:sort].to_s
    column = "created_at" unless SORTABLE_COLUMNS.include?(column)

    direction = params[:direction].to_s.downcase
    direction = "desc" unless SORT_DIRECTIONS.include?(direction)

    scope.order(Arel.sql("#{column} #{direction.upcase}")).order(id: :desc)
  end

  # The inbox is always paginated (unlike the legacy "bare array" mode), so the
  # shared helper's nil return (no `page` param) is replaced with page 1.
  def page_params
    super || { page: 1, per_page: Api::Paginatable::DEFAULT_PER_PAGE }
  end
end
