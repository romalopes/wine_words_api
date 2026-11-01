# frozen_string_literal: true

# Authorization for the Producer catalogue.
#
# Mirrors the app's role model (see User):
#   * wine_manager? (Admin / Editor / Reviewer) may create and edit producers;
#   * destroying a producer is a destructive catalogue action reserved for
#     catalogue managers (Admin / Editor).
class ProducerPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create? = user&.wine_manager?
  def update? = user&.catalogue_manager?
  def destroy? = user&.catalogue_manager?
end