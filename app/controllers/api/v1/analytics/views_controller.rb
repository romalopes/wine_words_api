module Api
  module V1
    module Analytics
      class ViewsController < ApplicationController
        # Public beacon — anonymous fallback when no credentials are supplied.
        # Invalid/expired JWTs return 401 via optional auth (ADR-014).
        skip_before_action :authenticate_user!, only: [ :create ]
        skip_before_action :enforce_email_verification!, only: [ :create ]
        before_action :authenticate_optional_user!, only: [ :create ]

        ALLOWED_SOURCES = %w[direct search internal external].freeze
        VISITOR_UUID_RE = /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

        # POST /api/v1/analytics/views
        #
        # Neutral 202 contract: every structurally valid request returns
        # { accepted: true }, whether counted or intentionally ignored
        # (admin/author/opt-out/inaccessible). Never leak exclusion reasons.
        def create
          # Request validation
          if request.body.size.positive? && request.media_type != "application/json"
            return render json: { error: "Unsupported Media Type" }, status: :unsupported_media_type
          end

          event_type = params[:event_type]
          content_type = params[:content_type]
          content_id = params[:content_id]
          occurred_at = params[:occurred_at]
          source = params[:source]
          referrer = params[:referrer]
          viewport = params[:viewport]

          unless event_type == "view"
            return render json: { error: "Invalid event_type" }, status: :unprocessable_entity
          end

          unless ::Analytics::Event::CONTENT_TYPES.include?(content_type)
            return render json: { error: "Invalid content_type" }, status: :unprocessable_entity
          end

          content_id = content_id.to_i if content_id.is_a?(String) && content_id.match?(/\A\d+\z/)
          unless content_id.is_a?(Integer) && content_id.positive?
            return render json: { error: "Invalid content_id" }, status: :unprocessable_entity
          end

          if source.present? && !ALLOWED_SOURCES.include?(source)
            return render json: { error: "Invalid source" }, status: :unprocessable_entity
          end
          source = "direct" if source.blank?

          if referrer.present? && referrer.to_s.length > 500
            return render json: { error: "Invalid referrer" }, status: :unprocessable_entity
          end

          if viewport.present? && viewport.to_s.length > 32
            return render json: { error: "Invalid viewport" }, status: :unprocessable_entity
          end

          # Identity resolution
          visitor_header = request.headers["X-Visitor-ID"].presence
          if visitor_header && !visitor_header.match?(VISITOR_UUID_RE)
            return render json: { error: "Invalid visitor ID" }, status: :unprocessable_entity
          end
          identity = build_identity(visitor_header)

          # Enqueue async ingestion; controller returns immediately.
          # ActiveJob cannot serialize AR objects: pass only primitives.
          ::Analytics::IngestJob.perform_later(
            event_type: event_type,
            content_type: content_type,
            content_id: content_id,
            identity: identity,
            occurred_at: occurred_at,
            source: source,
            referrer: referrer,
            viewport: viewport,
            current_user_id: current_user&.id
          )

          render json: { accepted: true }, status: :accepted
        end

        private

        # Optional JWT auth: valid token -> current_user; invalid token -> 401;
        # absent token -> anonymous. Uses warden without raising for guests.
        def authenticate_optional_user!
          return if request.headers["Authorization"].blank?

          user = warden.authenticate(scope: :user)
          return if user

          render json: { error: "You need to sign in or sign up before continuing." }, status: :unauthorized
        end

        def build_identity(visitor_header)
          if current_user&.persisted? && !current_user.analytics_opt_out?
            "account:#{current_user.id}"
          else
            "visitor:#{visitor_header || SecureRandom.uuid}"
          end
        end
      end
    end
  end
end
