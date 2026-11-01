# Shipment tracking for a package (a singleton nested resource).
#
# Carrier-independent by design: a reviewer can always enter the carrier and
# consignment number (and the current status), and `refresh` asks the resolved
# provider for updates. The provider is inferred from the carrier name, so the
# frontend never has to know about provider keys.
#
# Issue #199 producer management: an owner/manager member of the producer may
# also read the tracking and add/update the producer-safe fields (carrier,
# consignment number, URL, estimated delivery) while the package is in a
# producer-manageable stage. They can never set the provider, the delivery
# status or `delivered_at` — confirming physical arrival stays editorial — and
# never alter the provider event history.
#
# A refresh never marks the package as arrived — only a person does that.
class Api::V1::ShipmentTrackingsController < ApplicationController
  include WinePackageAuthorizable

  audit_actions update: "shipment_tracking.updated",
                refresh: "shipment_tracking.refreshed"

  before_action :set_package
  # Reading is as broad as viewing the package (producer members included);
  # writing/refreshing is gated on the manage_tracking? tier.
  before_action :ensure_package_visible!, only: [ :show ]
  before_action :ensure_package_tracking_manageable!, only: %i[update refresh]

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

  # Same visibility as the package itself (editorial side, the recorder and the
  # producer's owner/manager members). A 404 rather than a 403 so the endpoint
  # never reveals that a package exists.
  def ensure_package_visible!
    authorize @package, :show?
  rescue Pundit::NotAuthorizedError
    render json: { error: "Wine package not found" }, status: :not_found
  end

  def tracking_params
    # :provider is accepted for explicit overrides; otherwise it is inferred
    # from the carrier (see ShipmentTracking#infer_provider_from_carrier).
    if WinePackagePolicy.new(current_user, @package).producer_member?
      # Producer-safe subset (issue #199 §4): no provider override, no delivery
      # status and no delivered_at — physical arrival is confirmed editorially.
      params.require(:shipment_tracking).permit(
        :carrier, :number, :url, :estimated_delivery_at
      )
    else
      params.require(:shipment_tracking).permit(
        :carrier, :number, :url, :provider, :status,
        :estimated_delivery_at, :delivered_at
      )
    end
  end

  def render_record_invalid(error)
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_entity
  end
end
