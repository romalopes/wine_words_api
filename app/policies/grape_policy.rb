# frozen_string_literal: true

# Authorization for the Grape catalogue.
#
# Any wine manager (Admin / Editor / Reviewer) may manage grapes, including
# linking grapes to wines; the grape catalogue is never publicly writable.
class GrapePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create? = user&.wine_manager?
  def index? = true
  def show? = true
  def update? = user&.wine_manager?
  def link_wine? = user&.wine_manager?
  alias_method :link_producer?, :link_wine?
  def destroy? = user&.catalogue_manager?
end