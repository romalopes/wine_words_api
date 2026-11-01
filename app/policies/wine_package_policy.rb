# frozen_string_literal: true

class WinePackagePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.catalogue_manager?
      return scope.none unless user

      scope.where(reviewer_id: user.id).or(scope.where(created_by_id: user.id))
    end
  end

  def index? = user.present?
  def show? = manageable? || record.created_by_id == user&.id
  def create? = user&.wine_manager?
  def update? = manageable?
  alias_method :destroy?, :update?
  alias_method :manage?, :update?

  private

  def manageable?
    user&.catalogue_manager? || record.reviewer_id == user&.id
  end
end