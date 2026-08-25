class Api::V1::ImagesController < ApplicationController
  ALLOWED_TYPES = { "wine" => Wine, "producer" => Producer, "review" => Review, "article" => Article }.freeze

  def create
    record = find_record
    return render json: { error: "Not found" }, status: :not_found unless record

    files = Array(params[:images]).compact_blank
    return render json: { error: "No images provided" }, status: :unprocessable_entity if files.empty?

    record.images.attach(files)
    render json: {
      imageable_type: record.class.name,
      imageable_id: record.id,
      images: record.images.map { |image| rails_blob_url(image) }
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Not found" }, status: :not_found
  end

  def destroy
    record = find_record
    return render json: { error: "Not found" }, status: :not_found unless record

    if record.respond_to?(:user_id) && record.user_id != current_user.id
      return render json: { error: "Forbidden" }, status: :forbidden
    end

    attachment = ActiveStorage::Attachment.find_by(
      id: params[:id], record: record, name: "images"
    )
    return render json: { error: "Not found" }, status: :not_found unless attachment

    attachment.purge
    head :no_content
  end

  private

  def find_record
    model = ALLOWED_TYPES[params[:imageable_type].to_s.downcase]
    return nil unless model

    if model.respond_to?(:find_by) && model.column_names.include?("slug")
      model.find_by(slug: params[:imageable_id]) || model.find(params[:imageable_id])
    else
      model.find(params[:imageable_id])
    end
  end

  def rails_blob_url(image)
    Rails.application.routes.url_helpers.rails_blob_url(image, host: request.base_url)
  end
end