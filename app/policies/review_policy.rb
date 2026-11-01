# frozen_string_literal: true

# Authorization for Review records.
#
#   * Published reviews are publicly readable; drafts are only visible to
#     their author and to wine managers (Admin / Editor / Reviewer).
#   * Authoring is limited to wine managers; authors may edit their own
#     reviews, any wine manager may edit all.
#   * Destroying is reserved for catalogue managers (Admin / Editor).
class ReviewPolicy < ApplicationPolicy
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