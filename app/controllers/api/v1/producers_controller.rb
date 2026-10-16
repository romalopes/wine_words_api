class Api::V1::ProducersController < ApplicationController
  audit_actions :create, :update, :destroy

  def log_description
    "#{audit_verb} producer \"#{@producer.name}\""
  end

  def log_objects
    [@producer, @producer&.address].compact
  end

  skip_before_action :authenticate_user!, only: [:index, :show, :search]
  # Only Admins and Editors may add, edit or delete producers.
  before_action :ensure_wine_manager!, only: [:create, :update, :destroy, :attach_logo, :remove_logo]
  before_action :set_producer, only: [:show, :update, :destroy, :attach_logo, :remove_logo, :link_wine]

  def index
    scope = Producer.eager_load(:country, :address)
                    .preload(logo_attachment: :blob,
                             images: { file_attachment: :blob }).order(:name)
    scope = scope.where(country_id: params[:country_id]) if params[:country_id].present?
    scope = scope.joins(:regions).where(regions: { id: params[:region_id] }) if params[:region_id].present?
    scope = scope.joins(:grapes).where(grapes: { id: params[:grape_id] }) if params[:grape_id].present?
    scope = scope.where(producer_type: params[:producer_type]) if params[:producer_type].present?
    scope = scope.where(active: ActiveModel::Type::Boolean.new.cast(params[:active])) if params[:active].present?
    scope = scope.where("producers.name ILIKE ?", "%#{params[:q]}%") if params[:q].present?
    return if render_paginated(scope) { |items| producers_list_json(items) }

    render json: producers_list_json(scope)
  end

  # JSON endpoint used by the wine form's "search producers" picker.
  def search
    query = params[:q].to_s.strip
    producers =
      if query.blank?
        Producer.none
      else
        Producer.includes(:country, :address).where("producers.name ILIKE ?", "%#{query}%").order(:name).limit(20)
      end

    render json: producers.map { |producer| producer_search_json(producer) }
  end

  # POST /api/v1/producers/:id/link_wine — assign a wine to this producer.
  def link_wine
    return render json: { error: "Forbidden" }, status: :forbidden unless current_user&.wine_manager?

    wine = Wine.find_by(slug: params[:wine_id]) || Wine.find_by(id: params[:wine_id])
    return render json: { error: "Wine not found" }, status: :not_found unless wine

    wine.update!(producer_id: @producer.id)
    render json: producer_json(@producer)
  end

  def show
    render json: producer_json(@producer)
  end

  def create
    @producer = Producer.new(producer_params)
    if @producer.save
      render json: producer_json(@producer), status: :created
    else
      render json: { errors: @producer.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @producer.update(producer_params)
      render json: producer_json(@producer)
    else
      render json: { errors: @producer.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @producer.destroy
    head :no_content
  end

  # POST /api/v1/producers/:id/logo — dedicated single logo upload.
  def attach_logo
    file = params[:logo]
    unless file.respond_to?(:tempfile) || file.respond_to?(:read)
      return render json: { errors: ["Logo file is missing"] }, status: :unprocessable_entity
    end
    unless Producer::ALLOWED_LOGO_TYPES.include?(file.content_type)
      return render json: { errors: ["Logo must be an image (PNG, JPEG, GIF, WEBP or SVG)"] },
                    status: :unprocessable_entity
    end
    if file.size > Producer::MAX_LOGO_SIZE
      return render json: { errors: ["Logo must be smaller than 10 MB"] }, status: :unprocessable_entity
    end

    @producer.logo.purge if @producer.logo.attached?
    @producer.logo.attach(file)
    render json: { logo_url: producer_logo_url(@producer) }
  end

  # DELETE /api/v1/producers/:id/logo
  def remove_logo
    @producer.logo.purge if @producer.logo.attached?
    head :no_content
  end

  private

  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def set_producer
    # Preload the logo and images (with attachment + blob) so producer_json's
    # logo_url / images do not fire per-image attachment and blob queries.
    @producer = Producer.includes(:country, :regions, :grapes, address: :country)
                        .preload(logo_attachment: :blob, images: { file_attachment: :blob })
                        .find_by!(slug: params[:id])
  end

  def producer_search_json(producer)
    {
      id: producer.id,
      slug: producer.slug,
      name: producer.name,
      address: producer.address&.street_address,
      email: producer.email,
      website: producer.website,
      description: producer.description,
      producer_type: producer.producer_type,
      instagram: producer.instagram,
      facebook: producer.facebook,
      country: country_json(producer.country),
      logo_url: producer_logo_url(producer)
    }
  end

  def producer_params
    permitted = params.require(:producer).permit(
      :name, :email, :website, :description, :producer_type,
      :instagram, :facebook, :legal_name, :phone,
      :founded_year, :active, :country_id,
      region_ids: [], grape_ids: [],
      address_attributes: [:id, :street_address, :city, :state, :postal_code, :country_id, :_destroy]
    )
    # Dedupe so duplicate submissions can't break the unique join indices.
    permitted[:region_ids] = permitted[:region_ids].map(&:to_i).uniq if permitted.key?(:region_ids)
    permitted[:grape_ids] = permitted[:grape_ids].map(&:to_i).uniq if permitted.key?(:grape_ids)
    permitted
  end

  def producers_list_json(scope)
    producers = scope.to_a
    wine_counts = Wine.where(producer_id: producers.map(&:id)).group(:producer_id).count
    producers.map do |producer|
      {
        id: producer.id,
        slug: producer.slug,
        name: producer.name,
        email: producer.email,
        producer_type: producer.producer_type,
        active: producer.active,
        country: country_json(producer.country),
        address: producer.address && { street_address: producer.address.street_address },
        logo_url: producer_logo_url(producer),
        images: image_urls(producer).first(1),
        wines_count: wine_counts.fetch(producer.id, 0)
      }
    end
  end

  def producer_json(producer, wines_count: nil)
    {
      id: producer.id,
      slug: producer.slug,
      name: producer.name,
      legal_name: producer.legal_name,
      address: address_json(producer.address),
      email: producer.email,
      website: producer.website,
      description: producer.description,
      producer_type: producer.producer_type,
      instagram: producer.instagram,
      facebook: producer.facebook,
      phone: producer.phone,
      founded_year: producer.founded_year,
      active: producer.active,
      country: country_json(producer.country),
      regions: ordered_by_name(producer.regions).map do |region|
        { id: region.id, name: region.name, country_name: region.country&.name }
      end,
      grapes: ordered_by_name(producer.grapes).map do |grape|
        { id: grape.id, name: grape.name, color: grape.color }
      end,
      logo_url: producer_logo_url(producer),
      images: image_urls(producer),
      wines_count: wines_count || producer.wines.count
    }

  end

  def ordered_by_name(association)
    association.loaded? ? association.sort_by { |record| record.name.to_s } : association.order(:name)
  end

  def address_json(address)
    return nil if address.blank?

    {
      id: address.id,
      street_address: address.street_address,
      city: address.city,
      state: address.state,
      postal_code: address.postal_code,
      country: country_json(address.country)
    }
  end

  def country_json(country)
    return nil if country.blank?

    { id: country.id, name: country.name, code: country.code, flag_emoji: country.flag_emoji }
  end

  def producer_logo_url(producer)
    return nil unless producer.logo.attached?

    Rails.application.routes.url_helpers.rails_blob_url(producer.logo, host: request.base_url)
  end

  def image_urls(record)
    images = record.images
    ordered = images.loaded? ? images.sort_by { |image| [image.position.to_i, image.id] } : images.ordered
    ordered.filter_map do |image|
      Rails.application.routes.url_helpers.rails_blob_url(
        image.file.blob,
        host: request.base_url
      ) if image.file.attached?
    end
  end
end
