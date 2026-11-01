# frozen_string_literal: true

# Authorization for Article records.
#
#   * Articles are publicly readable once published; drafts and archived
#     articles are only visible to their author and to wine managers.
#   * Authoring is limited to wine managers (Admin / Editor / Reviewer);
#     authors may edit their own articles, wine managers may edit any.
#   * Destroying is reserved for catalogue managers (Admin / Editor).
class ArticlePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope = super
      if user&.wine_manager?
        scope.all
      elsif user
        scope.where(user: user).or(scope.where(status: "published"))
      else
        scope.where(status: "published")
      end
    end
  end

  def show? = record.status == "published" || record.user == user || user&.wine_manager?

  def create? = user&.wine_manager?

  def update? = user&.wine_manager? || record.user == user

  def destroy? = user&.catalogue_manager?
end