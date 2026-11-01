# Typed attachments for a wine package and its individual wine lines
# (nested under /wine_packages/:wine_package_id — issue #199).
#
# Uploads are secure by construction:
#   * bytes go to Active Storage (Cloudflare R2 in production) through the
#     existing upload pipeline — no public/permanent R2 URLs are stored or
#     exposed, downloads are short-lived signed URLs generated per request;
#   * a producer member may only manage SHARED attachments on their producer's
#     packages, and only while the package is in a producer-editable stage;
#   * `internal` attachments are editorial-only and never leave the editorial
#     surface (never visible to the producer side, §8).
class Api::V1::WinePackageAttachmentsController < ApplicationController
  include WinePackageAuthorizable

  audit_actions create: "wine_package_attachment.created",
                destroy: "wine_package_attachment.deleted"

  before_action :set_package
  before_action :ensure_package_visible!, only: [ :index ]
  before_action :ensure_package_attachments_manageable!, only: %i[create destroy]
  before_action :set_attachment, only: [ :destroy ]

  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  def log_description
    "#{audit_verb} wine package attachment on package ##{@package&.id}"
  end

  def log_objects
    [ @package, @package&.producer, @attachment ].compact
  end

  # GET /api/v1/wine_packages/:wine_package_id/attachments
  #
  # Producer viewers see only their producer's SHARED attachments; editorial
  # viewers see everything. Internal files are never enumerated for producers.
  def index
    attachments = @package.wine_package_attachments
    attachments = attachments.shared unless editorial_viewer?

    render json: attachments.order(:created_at, :id).map { |attachment|
      WinePackageAttachmentSerializer.new(attachment, request.base_url).as_json
    }
  end

  # POST /api/v1/wine_packages/:wine_package_id/attachments
  def create
    attachment = @package.wine_package_attachments.new(attachment_params)
    @attachment = attachment

    # The producer side may only ever create shared attachments.
    attachment.visibility = "shared" if package_producer_member?

    attachment.file.attach(params[:file]) if params[:file].present?

    if attachment.save
      render json: WinePackageAttachmentSerializer.new(attachment.reload, request.base_url).as_json,
             status: :created
    else
      render json: { errors: attachment.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/wine_packages/:wine_package_id/attachments/:id
  #
  # A producer member may remove their producer's shared attachments while the
  # package is in a producer-editable stage; editors may remove anything.
  def destroy
    @attachment.destroy
    head :no_content
  end

  private

  def set_package
    @package = WinePackage.find(params[:wine_package_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine package not found" }, status: :not_found
  end

  def set_attachment
    @attachment = @package.wine_package_attachments.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine package attachment not found" }, status: :not_found
  end

  def ensure_package_visible!
    authorize @package, :show?
  rescue Pundit::NotAuthorizedError
    render json: { error: "Wine package not found" }, status: :not_found
  end

  def editorial_viewer?
    WinePackagePolicy.new(current_user, @package).editorial_viewer?
  end

  def package_producer_member?
    WinePackagePolicy.new(current_user, @package).producer_member?
  end

  def attachment_params
    params.require(:wine_package_attachment).permit(
      :wine_package_item_id, :attachment_type, :visibility, :caption
    )
  end

  def render_record_invalid(error)
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end
end
