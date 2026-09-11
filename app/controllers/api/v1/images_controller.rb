class Api::V1::ImagesController < ApplicationController
  include ImageAttributes

  ALLOWED_TYPES = { "wine" => Wine, "producer" => Producer, "review" => Review, "article" => Article }.freeze

  before_action :set_base_url
  before_action :find_record

  def create
    return render json: { error: "Not found" }, status: :not_found unless @record
    return render json: { error: "Forbidden" }, status: :forbidden unless authorized_to_modify?(@record)

    files = Array(params[:images]).compact_blank
    return render json: { error: "No images provided" }, status: :unprocessable_entity if files.empty?

    created = files.map { |file| attach_file(file) }
    invalid = created.reject(&:persisted?)
    return render json: { errors: invalid.flat_map { |img| img.errors.full_messages } }, status: :unprocessable_entity if invalid.any?

    render json: {
      imageable_type: @record.class.name,
      imageable_id: @record.id,
      images: image_details(@record)
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Not found" }, status: :not_found
  end

  def destroy
    return render json: { error: "Not found" }, status: :not_found unless @record
    return render json: { error: "Forbidden" }, status: :forbidden unless authorized_to_modify?(@record)

    image = @record.images.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless image

    remove_image(image)
    head :no_content
  end

  # PATCH /api/v1/images/reorder?imageable_type&imageable_id
  # body: { image_ids: [id, id, ...] } or { images: [{ id }, { id }, ...] }
  def reorder
    return render json: { error: "Not found" }, status: :not_found unless @record
    return render json: { error: "Forbidden" }, status: :forbidden unless authorized_to_modify?(@record)

    ordered = params[:image_ids].presence || params[:images].presence
    return render json: { error: "No image order provided" }, status: :unprocessable_entity if ordered.blank?

    ordered_ids = Array(ordered).filter_map { |x| x.is_a?(ActionController::Parameters) ? x[:id] : x }
    Image.reorder!(@record, ordered_ids)

    render json: { images: image_details(@record) }
  end

  # PATCH /api/v1/images/:id/primary?imageable_type&imageable_id
  def set_primary
    return render json: { error: "Not found" }, status: :not_found unless @record
    return render json: { error: "Forbidden" }, status: :forbidden unless authorized_to_modify?(@record)

    image = @record.images.find_by(id: params[:id])
    return render json: { error: "Not found" }, status: :not_found unless image

    image.make_primary!
    render json: { images: image_details(@record), primary_image: primary_image(@record) }
  end

  private

  def attach_file(file)
    Image.new(imageable: @record).tap do |img|
      img.file.attach(file)
      img.save
    end
  end

  def remove_image(image)
    was_primary = image.primary?
    image.file.purge
    image.destroy
    return unless was_primary

    # Promote the next remaining image if the only primary was removed.
    next_up = @record&.images&.ordered&.first
    next_up&.update_columns(primary: true)
  end

  def authorized_to_modify?(record)
    return false unless record

    if record.respond_to?(:user_id)
      current_user&.wine_manager? || record.user_id == current_user&.id
    else
      current_user&.wine_manager?
    end
  end

  def find_record
    model = ALLOWED_TYPES[params[:imageable_type].to_s.downcase]
    return @record = nil unless model

    @record =
      if model.column_names.include?("slug")
        model.find_by(slug: params[:imageable_id]) || model.find(params[:imageable_id])
      else
        model.find(params[:imageable_id])
      end
  rescue ActiveRecord::RecordNotFound
    @record = nil
  end

  def set_base_url
    @base_url = request.base_url
  end
end