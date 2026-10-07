class Api::V1::ArticleProjectNotebooksController < ApplicationController
  include ArticleProjectAuthorizable

  before_action :set_article_project
  before_action :ensure_article_project_manageable!
  before_action :set_article_project_vintage
  before_action :set_notebook, only: %i[show update destroy create_review]

  rescue_from ActiveRecord::RecordInvalid, with: :render_record_invalid
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::StaleObjectError, with: :render_stale_write

  def index
    render json: @article_project_vintage.article_project_notebooks.ordered.map { |notebook| notebook_json(notebook) }
  end

  def create
    notebook = @article_project_vintage.article_project_notebooks.new(notebook_params)
    notebook.position = next_position if notebook.position.nil?
    notebook.save!

    render json: notebook_json(notebook), status: :created
  end

  def show
    render json: notebook_json(@notebook)
  end

  def update
    return if require_lock_version!

    @notebook.update!(notebook_params)
    render json: notebook_json(@notebook)
  end

  def destroy
    return if require_lock_version!

    @notebook.lock_version = notebook_lock_version
    @notebook.destroy!
    head :no_content
  end

  # POST /api/v1/article_projects/:article_project_id/article_project_vintages/:article_project_vintage_id/notebooks/:notebook_id/review
  # Copies the notebook only once. The notebook remains editable and the resulting
  # review is independently editable through the normal review workflow.
  def create_review
    review = nil

    ArticleProject.transaction do
      review = Review.create!(
        vintage: @article_project_vintage.vintage,
        user: current_user,
        title: @notebook.title,
        comment: @notebook.content,
        score: 80,
        status: "draft"
      )
      @article_project.article_project_reviews.create!(review: review)
    end

    render json: ReviewSerializer.new(review, request.base_url, liked_ids: Likes.liked_ids_for([review], current_user)).as_json,
           status: :created
  end

  private

  def set_article_project
    @article_project = article_projects_scope.find(params[:article_project_id])
  end

  def ensure_article_project_manageable!
    return if article_project_manageable?(@article_project)

    render json: { error: "Article project not found" }, status: :not_found
  end

  def set_article_project_vintage
    @article_project_vintage = @article_project.article_project_vintages.find(params[:article_project_vintage_id])
  end

  def set_notebook
    @notebook = @article_project_vintage.article_project_notebooks.find(params[:notebook_id])
  end

  def notebook_params
    params.require(:article_project_notebook).permit(:title, :content, :position, :lock_version)
  end

  def notebook_lock_version
    params.dig(:article_project_notebook, :lock_version).to_i
  end

  def require_lock_version!
    return false if params.dig(:article_project_notebook, :lock_version).present?

    render json: { error: "lock_version is required" }, status: :unprocessable_entity
    true
  end

  def next_position
    @article_project_vintage.article_project_notebooks.maximum(:position).to_i + 1
  end

  def notebook_json(notebook)
    {
      id: notebook.id,
      title: notebook.title,
      content: notebook.content,
      position: notebook.position,
      lock_version: notebook.lock_version,
      created_at: notebook.created_at&.iso8601,
      updated_at: notebook.updated_at&.iso8601
    }
  end

  def render_record_invalid(error)
    render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  def render_not_found
    render json: { error: "Article project notebook not found" }, status: :not_found
  end

  def render_stale_write(_error)
    render json: { error: "Notebook has changed. Reload and try again." }, status: :conflict
  end
end