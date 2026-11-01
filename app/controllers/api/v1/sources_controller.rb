# Read-only overview of content sources (manual / substack / wine_front) with
# per-source counts of reviews and articles. Sources are a fixed enum on both
# models rather than a table, so this computes the counts directly (mirroring
# categories#counts) instead of iterating records.
class Api::V1::SourcesController < ApplicationController
  include Pundit::Authorization

  # GET /api/v1/sources
  def index
    review_scope = policy_scope(Review)
    article_scope = policy_scope(Article)

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

  def source_label(value)
    {
      "manual" => "Manual",
      "substack" => "Substack",
      "wine_front" => "WineFront"
    }[value] || value.titleize
  end
end
