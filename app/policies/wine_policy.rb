# frozen_string_literal: true

# Authorization for Wine records.
#
# Mirrors the app's role model (see User):
#   * wine_manager? (Admin / Editor / Reviewer) may create and edit wines;
#   * destroying a wine is a destructive catalogue action reserved for
#     catalogue managers (Admin / Editor);
#   * wines are publicly readable.
class WinePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def show? = true

  def create? = user&.wine_manager?

  def update? = user&.wine_manager?

  def destroy? = user&.catalogue_manager?
end