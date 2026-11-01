# frozen_string_literal: true

# Authorization for Vintage records (nested under Wine).
#
# Any wine manager (Admin / Editor / Reviewer) may add vintages to a wine.
# Vintages are catalogue data and cannot be created by regular Readers.
class VintagePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create? = user&.wine_manager?
  def update? = user&.wine_manager?
  def destroy? = user&.catalogue_manager?
end