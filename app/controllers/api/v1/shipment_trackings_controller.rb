# Shipment tracking for a package (a singleton nested resource).
#
# Carrier-independent by design: a reviewer can always enter the carrier and
# consignment number (and the current status), and `refresh` asks the resolved
# provider for updates. The provider is inferred from the carrier name, so the
# frontend never has to know about provider keys.
#
# A refresh never marks the package as arrived — only a person does that.
class Api::V1::ShipmentTrackingsController < ApplicationController
  include WinePackageAuthorizable

  audit_actions :update, refresh: "shipment_tracking.refreshed"

  before_action :set_package
  before_action :ensure_package_manageable!

  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid

  # An upsert that actually created the row is audited as a creation.
  def audit_action_name
    return "shipment_tracking.created" if action_name == "update" && @tracking_created

    super
  end

  def log_description
    "#{audit_verb} tracking for wine package ##{@package&.id}"
  end

  def log_objects
    [ @package, @tracking, @package&.producer ].compact
  end

  # GET /api/v1/wine_packages/:wine_package_id/shipment_tracking
  def show
    tracking = @package.shipment_tracking
    return render json: { error: "No tracking recorded for this package" },
                  status: :not_found if tracking.nil?

    @tracking = tracking
    render json: ShipmentTrackingSerializer.new(tracking, request.base_url).as_json
  end

  # PATCH /api/v1/wine_packages/:wine_package_id/shipment_tracking
  #
  # Upsert: a package either gains its tracking row here or updates the one it
  # has, so the UI needs a single "Save tracking" call.
  def update
    tracking = @package.shipment_tracking || @package.build_shipment_tracking
    @tracking = tracking
    tracked_before = tracking.persisted?
    @tracking_created = !tracked_before

    tracking.assign_attributes(tracking_params)

    if tracking.save
      render json: ShipmentTrackingSerializer.new(tracking, request.base_url).as_json,
             status: tracked_before ? :ok : :created
    else
      render json: { errors: tracking.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /api/v1/wine_packages/:wine_package_id/shipment_tracking/refresh
  def refresh
    tracking = @package.shipment_tracking
    return render json: { error: "No tracking recorded for this package" },
                  status: :unprocessable_entity if tracking.nil?

    @tracking = tracking
    if tracking.number.blank?
      return render json: { error: "Add a consignment number before refreshing" },
                    status: :unprocessable_entity
    end

    tracking.refresh!
    render json: ShipmentTrackingSerializer.new(tracking.reload, request.base_url).as_json
  end

  private

  def set_package
    @package = WinePackage.find(params[:wine_package_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Wine package not found" }, status: :not_found
  end

  def tracking_params
    # :provider is accepted for explicit overrides; otherwise it is inferred
    # from the carrier (see ShipmentTracking#infer_provider_from_carrier).
    params.require(:shipment_tracking).permit(
      :carrier, :number, :url, :provider, :status,
      :estimated_delivery_at, :delivered_at
    )
  end

  def render_record_invalid(error)
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end
end
