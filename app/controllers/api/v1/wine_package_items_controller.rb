# The wine lines inside a package (nested under /wine_packages/:wine_package_id).
#
# Items are where the review workflow is actually driven: marking a line as
# review_requested makes it blocking, linking a published review releases it,
# and `create_review` starts a review through the ordinary Review path.
# Completion is re-evaluated automatically by the model hooks; the explicit
# CheckCompletion calls below cover the one case a hook cannot see (flipping
# review_requested off, which removes the last blocking line).
class Api::V1::WinePackageItemsController < ApplicationController
  include WinePackageAuthorizable

  audit_actions :create, :update, :destroy,
                create_review: "wine_package_item.review_created"

  before_action :set_package
  before_action :ensure_package_manageable!
  before_action :set_item, only: [ :update, :destroy, :create_review ]

  rescue_from WinePackages::Error, with: :render_workflow_error
  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  def log_description
    "#{audit_verb} #{@item&.label || 'wine'} on package ##{@package&.id}"
  end

  def log_objects
    [ @package, @item, @package&.producer ].compact
  end

  # POST /api/v1/wine_packages/:wine_package_id/items
  def create
    item = @package.wine_package_items.new(item_params)
    @item = item

    if item.save
      WinePackages::CheckCompletion.call(@package)
      render json: WinePackageItemSerializer.new(item, request.base_url).as_json,
             status: :created
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH /api/v1/wine_packages/:wine_package_id/items/:id
  def update
    if @item.update(item_params)
      # Removing the last blocking line (review_requested -> false) can complete
      # the package; the model hook only covers review link changes.
      WinePackages::CheckCompletion.call(@package)
      render json: WinePackageItemSerializer.new(@item.reload, request.base_url).as_json
    else
      render json: { errors: @item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /api/v1/wine_packages/:wine_package_id/items/:id
  def destroy
    @item.destroy
    head :no_content
  end

  # POST /api/v1/wine_packages/:wine_package_id/items/:id/create_review
  #
  # Creates the review through the existing Review path (same validations, slug,
  # images) and links it to the item. Passing status: "published" creates and
  # completes in one step.
  def create_review
    review = WinePackages::CreateReviewFromPackage.call(
      @item, user: current_user, attributes: review_params
    )
    @review = review

    render json: ReviewSerializer.new(review, request.base_url).as_json, status: :created
  end

  private

  def set_package
    @package = WinePackage.find(params[:wine_package_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine package not found" }, status: :not_found
  end

  def set_item
    @item = @package.wine_package_items.includes(:vintage, :review).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine package item not found" }, status: :not_found
  end

  def item_params
    params.require(:item).permit(
      :vintage_id, :quantity, :review_requested, :condition, :notes,
      :received_at, :review_id
    )
  end

  def review_params
    params.fetch(:review, {}).permit(
      :title, :comment, :score, :status, :published_at,
      :drink_from, :drink_to, :drink_plus, images: [], category_ids: []
    )
  end

  def render_workflow_error(error)
    render json: { error: error.message }, status: :unprocessable_entity
  end

  def render_record_invalid(error)
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end
end
