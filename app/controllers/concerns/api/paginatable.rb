# Shared pagination for Api::V1 index endpoints.
#
# Two modes, driven by the presence of the `page` query param:
#   - `?page=N` (optionally `&per_page=M`, default 20, capped at 100):
#       the scope is sliced server-side and the response is an envelope:
#       { items:, page:, per_page:, total_count:, total_pages: }
#   - no `page` param: the full scope is returned as a plain array
#     (unchanged legacy behaviour, used by form pickers and health checks).
module Api
  module Paginatable
    extend ActiveSupport::Concern

    DEFAULT_PER_PAGE = 20
    MAX_PER_PAGE = 100

    private

    # Returns { page:, per_page: } when pagination is requested, nil otherwise.
    def page_params
      return nil if params[:page].blank?

      page = params[:page].to_i
      return nil if page < 1

      per_page =
        if params[:per_page].present?
          params[:per_page].to_i.clamp(1, MAX_PER_PAGE)
        else
          DEFAULT_PER_PAGE
        end

      { page: page, per_page: per_page }
    end

    # Renders the paginated envelope and returns true when `page` was given.
    # Yields the page slice to build the serialized items.
    def render_paginated(scope)
      pagination = page_params
      return false unless pagination

      total_count = scope.count
      items = scope
        .limit(pagination[:per_page])
        .offset((pagination[:page] - 1) * pagination[:per_page])

      render json: {
        items: yield(items),
        page: pagination[:page],
        per_page: pagination[:per_page],
        total_count: total_count,
        total_pages: (total_count.to_f / pagination[:per_page]).ceil,
      }
      true
    end
  end
end