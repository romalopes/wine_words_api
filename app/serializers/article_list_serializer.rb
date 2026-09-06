# Lean serializer used by Api::V1::ArticlesController#index (list views) only.
# Ships only the fields the list/table UIs render, avoiding the full detail
# payload (body, tags, wines, producers, reviews, images, etc.).
class ArticleListSerializer
  def initialize(article, base_url = nil)
    @article = article
    @base_url = base_url
  end

  def as_json
    {
      id: @article.id,
      slug: @article.slug,
      title: @article.title,
      abstract: @article.abstract,
      status: @article.status,
      author_name: @article.user&.name || @article.user&.email || "Unknown",
      user_id: @article.user_id,
      category: @article.categories.map(&:name).join(", ").presence,
      categories: @article.categories.map { |c| { id: c.id, name: c.name, slug: c.slug } },
      published_at: @article.published_at&.iso8601,
      created_at: @article.created_at&.iso8601
    }
  end
end