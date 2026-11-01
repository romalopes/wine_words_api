# frozen_string_literal: true

class ArticleProjectPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.catalogue_manager?
      return scope.none unless user

      scope.where(created_by_id: user.id)
    end
  end

  def index? = user.present?
  def show? = manageable?
  def create? = user&.wine_manager?
  def lookup? = create?
  def update? = manageable?
  def destroy? = manageable?
  def manage? = manageable?

  private

  def manageable?
    user&.catalogue_manager? || record.created_by_id == user&.id
  end
end