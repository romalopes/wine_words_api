class Api::V1::ArticleProjectsController < ApplicationController
  include ArticleProjectAuthorizable

  SORTS = {
    "name" => "name ASC, id ASC",
    "deadline" => "deadline ASC NULLS LAST, id DESC",
    "created_at" => "created_at DESC, id DESC",
    "updated_at" => "updated_at DESC, id DESC"
  }.freeze

  before_action :ensure_article_project_creator!, only: %i[create lookup]
  before_action :set_article_project, only: %i[show update destroy]
  before_action :ensure_article_project_manageable!, only: %i[update destroy]

  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
  rescue_from ActiveRecord::StaleObjectError, with: :render_stale_write
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found

  # GET /api/v1/article_projects
  def index
    article_projects = article_projects_scope.includes(association_includes).order(sort_order)
    article_projects = article_projects.where(project_status: params[:project_status]) if params[:project_status].present?
    article_projects = article_projects.where(drafting_status: params[:drafting_status]) if params[:drafting_status].present?
    article_projects = article_projects.where(article_id: params[:article_id]) if params[:article_id].present?
    article_projects = article_projects.where("deadline < ?", Date.current) if params[:overdue] == "true"
    article_projects = article_projects.where.not(project_status: %w[published cancelled]) if params[:overdue] == "true"
    if params[:query].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:query].strip)}%"
      article_projects = article_projects.where("name ILIKE :query OR publication ILIKE :query", query: query)
    end

    return if render_paginated(article_projects) { |items| serialize(items, detail: false) }

    render json: serialize(article_projects, detail: false)
  end

  # GET /api/v1/article_projects/lookup?kind=article|producer|vintage|review&q=...
  # Minimal, permission-scoped records for the assignment form. Keeping this
  # separate from the public catalogue feeds prevents the form from depending on
  # their broad serializer contracts and ensures Reviewers only see Articles and
  # Reviews that they may link.
  def lookup
    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    render json: case params[:kind]
                 when "article" then lookup_articles(query)
                 when "producer" then lookup_producers(query)
                 when "vintage" then lookup_vintages(query)
                 when "review" then lookup_reviews(query)
                 else
                   { error: "Unsupported lookup kind" }
                 end,
           status: %w[article producer vintage review].include?(params[:kind]) ? :ok : :unprocessable_entity
  end

  # GET /api/v1/article_projects/:id
  def show
    render json: ArticleProjectSerializer.new(@article_project).as_json
  end

  # POST /api/v1/article_projects
  def create
    article_project = ArticleProject.new(article_project_params)
    article_project.created_by = current_user
    validate_linked_records!(article_project)
    article_project.save!

    render json: ArticleProjectSerializer.new(load_article_project(article_project.id)).as_json, status: :created
  end

  # PATCH /api/v1/article_projects/:id
  def update
    return if require_lock_version!

    @article_project.assign_attributes(article_project_params)
    validate_linked_records!(@article_project)
    @article_project.save!

    render json: ArticleProjectSerializer.new(load_article_project(@article_project.id)).as_json
  end

  # DELETE /api/v1/article_projects/:id
  def destroy
    @article_project.destroy!
    head :no_content
  end

  private

  def association_includes
    {
      article: [],
      created_by: [],
      article_project_producers: :producer,
      article_project_vintages: { vintage: :wine },
      article_project_reviews: { review: { vintage: :wine } }
    }
  end

  def load_article_project(id)
    article_projects_scope.includes(association_includes).find(id)
  end

  def set_article_project
    @article_project = load_article_project(params[:id])
  end

  def ensure_article_project_manageable!
    return if article_project_manageable?(@article_project)

    render json: { error: "Article project not found" }, status: :not_found
  end

  def sort_order
    SORTS.fetch(params[:sort], SORTS.fetch("updated_at"))
  end

  def serialize(article_projects, detail:)
    article_projects.map { |article_project| ArticleProjectSerializer.new(article_project, detail: detail).as_json }
  end

  def article_project_params
    params.require(:article_project).permit(
      :name, :publication, :editor_name, :editor_email, :project_status,
      :drafting_status, :deadline, :target_word_count, :description, :article_id,
      :lock_version,
      article_project_producers_attributes: %i[id producer_id contacted request_confirmed notes _destroy],
      article_project_vintages_attributes: %i[id vintage_id requested received selected tasted date_received bottle_condition notes _destroy],
      article_project_reviews_attributes: %i[id review_id _destroy]
    )
  end

  # An update must carry the version last read by the client, including when its
  # only change is a nested association. Active Record turns a mismatch into the
  # StaleObjectError handled above.
  def require_lock_version!
    return false if params.dig(:article_project, :lock_version).present?

    render json: { error: "lock_version is required" }, status: :unprocessable_entity
    true
  end

  def validate_linked_records!(article_project)
    validate_article_access!(article_project.article) if article_project.article_id.present?
    article_project.article_project_producers.each { |row| validate_producer_access!(row.producer) unless row.marked_for_destruction? }
    article_project.article_project_vintages.each { |row| validate_vintage_access!(row.vintage) unless row.marked_for_destruction? }
    article_project.article_project_reviews.each { |row| validate_review_access!(row.review) unless row.marked_for_destruction? }
  end

  def lookup_articles(query)
    scope = Article.where("title ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
    scope = scope.where(user_id: current_user.id) unless current_user.catalogue_manager?
    scope.order(:title).limit(20).map { |article| { id: article.id, title: article.title, slug: article.slug, status: article.status } }
  end

  def lookup_producers(query)
    Producer.where("name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
            .order(:name).limit(20)
            .map { |producer| { id: producer.id, name: producer.name, slug: producer.slug } }
  end

  def lookup_vintages(query)
    scope = Vintage.joins(:wine).includes(wine: :producer)
                   .where("wines.name ILIKE ? OR CAST(vintages.year AS TEXT) ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
    scope = scope.where(wines: { producer_id: params[:producer_id] }) if params[:producer_id].present?
    scope.order("wines.name ASC, vintages.year DESC").limit(20).map do |vintage|
      wine = vintage.wine
      { id: vintage.id, display_name: vintage.name, year: vintage.year, wine_name: wine.name, wine_slug: wine.slug, producer_id: wine.producer_id }
    end
  end

  def lookup_reviews(query)
    scope = Review.joins(vintage: :wine).includes(vintage: :wine)
                  .where("reviews.title ILIKE ? OR wines.name ILIKE ?", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%", "%#{ActiveRecord::Base.sanitize_sql_like(query)}%")
    scope = scope.where(user_id: current_user.id) unless current_user.catalogue_manager?
    scope.order(created_at: :desc).limit(20).map do |review|
      { id: review.id, slug: review.slug, title: review.title, wine_name: review.vintage.wine.name, vintage_year: review.vintage.year }
    end
  end

  def validate_article_access!(article)
    return if current_user.catalogue_manager? || article.user_id == current_user.id

    raise ActiveRecord::RecordNotFound
  end

  def validate_review_access!(review)
    return if current_user.catalogue_manager? || review.user_id == current_user.id

    raise ActiveRecord::RecordNotFound
  end

  # Producers and vintages are catalogue records. A Reviewer is a wine manager
  # and can select existing catalogue records, while foreign IDs remain blocked
  # by Rails' nested-association lookup scoped to this ArticleProject.
  def validate_producer_access!(producer)
    raise ActiveRecord::RecordNotFound unless producer.present? && current_user.wine_manager?
  end

  def validate_vintage_access!(vintage)
    raise ActiveRecord::RecordNotFound unless vintage.present? && current_user.wine_manager?
  end

  def render_record_invalid(error)
    render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  def render_stale_write(_error)
    render json: { error: "Article project has changed. Reload and try again." }, status: :conflict
  end

  def render_not_found
    render json: { error: "Article project not found" }, status: :not_found
  end
end