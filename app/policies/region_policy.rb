# frozen_string_literal: true

class RegionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  def index? = true
  def show? = true
  def create? = user&.wine_manager?
  def update? = user&.wine_manager?
  def destroy? = user&.wine_manager?
  def link_wine? = user&.wine_manager?
  alias_method :link_producer?, :link_wine?
end
