# Read-only overview of content sources (manual / substack / wine_front) with
# per-source counts of reviews and articles. Sources are a fixed enum on both
# models rather than a table, so this computes the counts directly (mirroring
# categories#counts) instead of iterating records.
class Api::V1::SourcesController < ApplicationController
  before_action :ensure_wine_manager!

  # GET /api/v1/sources
  def index
    manager = current_user.wine_manager?
    review_scope = manager ? Review.all : Review.published
    article_scope = manager ? Article.all : Article.published

    review_counts = review_scope.group(:source).count
    article_counts = article_scope.group(:source).count

    sources = Review::SOURCES.map do |value|
      {
        source: value,
        label: source_label(value),
        reviews_count: review_counts[value] || 0,
        articles_count: article_counts[value] || 0
      }
    end

    render json: { sources: sources }
  end

  private

  # Matches the helper of the same name on the other management controllers
  # (it is intentionally defined per-controller rather than shared).
  def ensure_wine_manager!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def source_label(value)
    {
      "manual" => "Manual",
      "substack" => "Substack",
      "wine_front" => "WineFront"
    }[value] || value.titleize
  end
end
