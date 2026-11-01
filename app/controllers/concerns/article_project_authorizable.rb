module ArticleProjectAuthorizable
  extend ActiveSupport::Concern

  private

  def article_projects_scope
    policy_scope(ArticleProject)
  end

  def ensure_article_project_creator!
    authorize ArticleProject, action_name == "lookup" ? :lookup? : :create?
  end

  def article_project_manageable?(article_project)
    article_project && ArticleProjectPolicy.new(current_user, article_project).manage?
  end
end