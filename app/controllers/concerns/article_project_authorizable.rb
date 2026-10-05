module ArticleProjectAuthorizable
  extend ActiveSupport::Concern

  private

  def article_projects_scope
    return ArticleProject.all if current_user&.catalogue_manager?

    ArticleProject.where(created_by_id: current_user&.id)
  end

  def ensure_article_project_creator!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def article_project_manageable?(article_project)
    current_user&.catalogue_manager? || article_project&.created_by_id == current_user&.id
  end
end