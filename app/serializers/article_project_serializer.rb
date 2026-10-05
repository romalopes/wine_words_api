class ArticleProjectSerializer
  def initialize(article_project, detail: true)
    @article_project = article_project
    @detail = detail
  end

  def as_json
    payload = base_payload
    return payload unless @detail

    payload.merge(
      description: @article_project.description,
      actual_word_count: @article_project.actual_word_count,
      word_count_remaining: @article_project.word_count_remaining,
      article: article_json,
      article_project_producers: @article_project.article_project_producers.map { |row| producer_json(row) },
      article_project_vintages: @article_project.article_project_vintages.map { |row| vintage_json(row) },
      article_project_reviews: @article_project.article_project_reviews.map { |row| review_json(row) }
    )
  end

  private

  def base_payload
    {
      id: @article_project.id,
      name: @article_project.name,
      publication: @article_project.publication,
      editor_name: @article_project.editor_name,
      editor_email: @article_project.editor_email,
      project_status: @article_project.project_status,
      drafting_status: @article_project.drafting_status,
      deadline: @article_project.deadline&.iso8601,
      target_word_count: @article_project.target_word_count,
      overdue: @article_project.overdue?,
      lock_version: @article_project.lock_version,
      created_by: { id: @article_project.created_by_id, display_name: @article_project.created_by&.user_name || @article_project.created_by&.email },
      counts: @article_project.vintage_counts,
      created_at: @article_project.created_at&.iso8601,
      updated_at: @article_project.updated_at&.iso8601
    }
  end

  def article_json
    return nil unless @article_project.article
    { id: @article_project.article.id, slug: @article_project.article.slug, title: @article_project.article.title, status: @article_project.article.status }
  end

  def producer_json(row)
    { id: row.id, producer: { id: row.producer.id, name: row.producer.name, slug: row.producer.slug }, contacted: row.contacted, request_confirmed: row.request_confirmed, notes: row.notes }
  end

  def vintage_json(row)
    vintage = row.vintage
    wine = vintage.wine
    { id: row.id, vintage: { id: vintage.id, display_name: vintage.name, year: vintage.year, wine_name: wine&.name, wine_slug: wine&.slug, producer_id: wine&.producer_id }, requested: row.requested, received: row.received, selected: row.selected, tasted: row.tasted, date_received: row.date_received&.iso8601, bottle_condition: row.bottle_condition, notes: row.notes }
  end

  def review_json(row)
    review = row.review
    { id: row.id, review: { id: review.id, slug: review.slug, title: review.title, wine_name: review.vintage&.wine&.name, vintage_year: review.vintage&.year } }
  end
end