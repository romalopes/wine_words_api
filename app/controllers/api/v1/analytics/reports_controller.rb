module Api
  module V1
    module Analytics
      # Reporting endpoints (Phase 7).
      #
      # All endpoints require authenticated user with Reviewer, Editor, or Admin role.
      # Returns 401 for unauthenticated, 403 for insufficient role, 404 for
      # out-of-scope content (never 403 to avoid existence disclosure).
      #
      # Common query params:
      #   period: 7d | 30d | 90d | 1y | all (default: 30d)
      #   start_date / end_date: YYYY-MM-DD (Sydney dates, narrow period)
      #   sort: views | unique_viewers | likes | comments | engagement_rate | published_at
      #   direction: asc | desc
      #   page / per_page: pagination
      #   grouping: day | week | none (for timeseries/content_detail)
      #   include_zero_views: boolean (for top_content)
      class ReportsController < ApplicationController
        before_action :authenticate_user!
        before_action :enforce_email_verification!
        before_action :require_reporting_access!

        # GET /api/v1/analytics/summary
        def summary
          period, period_error = resolve_period
          return render_period_error(period_error) if period_error

          result = ::Analytics::Summary.call(@scope, period, reporting_params)

          render json: result
        end

        # GET /api/v1/analytics/top_content
        def top_content
          period, period_error = resolve_period
          return render_period_error(period_error) if period_error

          result = ::Analytics::TopContent.call(@scope, period, reporting_params)

          render json: result
        end

        # GET /api/v1/analytics/content/:content_type/:id
        def content_detail
          period, period_error = resolve_period
          return render_period_error(period_error) if period_error

          content_type = params[:content_type].to_s.classify
          content_id = params[:id].to_i

          unless %w[Article Review Wine].include?(content_type)
            return render json: { error: "Invalid content_type" }, status: :unprocessable_entity
          end

          result = ::Analytics::ContentDetail.call(@scope, period, content_type, content_id, reporting_params)

          if result.nil?
            return render json: { error: "Not found" }, status: :not_found
          end

          render json: result
        end

        # GET /api/v1/analytics/timeseries
        def timeseries
          period, period_error = resolve_period
          return render_period_error(period_error) if period_error

          result = ::Analytics::Timeseries.call(@scope, period, reporting_params)

          render json: result
        end

        # GET /api/v1/analytics/wine-insights
        def wine_insights
          period, period_error = resolve_period
          return render_period_error(period_error) if period_error

          result = ::Analytics::WineInsights.call(@scope, period, reporting_params)

          render json: result
        end

        private

        def require_reporting_access!
          @scope = ::Analytics::Scope.new(current_user)
          return if @scope.reporting_access?

          render json: { error: "Forbidden" }, status: :forbidden
        end

        def resolve_period
          ::Analytics::Period.resolve(
            params,
            max_range_days: Rails.application.config.analytics[:max_custom_range_days],
            history_from: ::Analytics::Event.accepted.minimum(:viewed_at)
          )
        end

        def render_period_error(error)
          message = case error
          when ::Analytics::Period::INVALID_PERIOD
            "period must be one of: #{::Analytics::Period::PERIOD_TOKENS.join(', ')}"
          when ::Analytics::Period::INVALID_DATE_RANGE
            "start_date/end_date must be valid YYYY-MM-DD dates, end_date >= start_date, and within the period window"
          when ::Analytics::Period::RANGE_TOO_LONG
            "custom date range exceeds maximum of #{Rails.application.config.analytics[:max_custom_range_days]} days"
          else
            "Invalid period"
          end
          render json: { error: message }, status: :unprocessable_entity
        end

        def reporting_params
          # Extract and whitelist params for downstream services
          params.permit(
            :sort, :direction, :page, :per_page,
            :grouping, :include_zero_views,
            :start_date, :end_date, :period
          ).to_h.symbolize_keys
        end
      end
    end
  end
end