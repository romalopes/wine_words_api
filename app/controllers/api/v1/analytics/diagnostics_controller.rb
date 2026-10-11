module Api
  module V1
    module Analytics
      # Admin-only diagnostics for analytics events (Phase 11).
      #
      # Disabled by default; requires Admin + explicit debug permission
      # (via AppSetting `analytics_diagnostics_enabled`).
      #
      # Endpoints:
      #   GET /api/v1/analytics/diagnostics/accepted
      #   GET /api/v1/analytics/diagnostics/exclusion_reasons
      class DiagnosticsController < ApplicationController
        before_action :authenticate_admin!
        before_action :require_diagnostics_enabled!

        # GET /api/v1/analytics/diagnostics/accepted
        def accepted
          result = ::Analytics::Diagnostics.accepted_events(diagnostics_params)
          render json: result
        end

        # GET /api/v1/analytics/diagnostics/exclusion_reasons
        def exclusion_reasons
          result = ::Analytics::Diagnostics.exclusion_reasons(diagnostics_params)
          render json: result
        end

        private

        def require_diagnostics_enabled!
          enabled = AppSetting.get("analytics_diagnostics_enabled", false)
          unless enabled
            render json: {
              error: "Diagnostics disabled",
              message: "Enable via AppSetting 'analytics_diagnostics_enabled' (Admin only)"
            }, status: :forbidden
          end
        end

        def diagnostics_params
          params.permit(
            :page, :per_page,
            :content_type, :viewable_id,
            :start_date, :end_date
          ).to_h.symbolize_keys
        end
      end
    end
  end
end