# frozen_string_literal: true

# Authorization for WineProfile records (security audit issue #23).
#
# Wine profiles are a public catalogue resource: anyone may list/read them.
# Mutations are restricted to wine managers (Admin / Editor / Reviewer) — the
# same rule as TasteParameterPolicy, so a self-registered Guest/Reader can no
# longer create, edit or delete profiles through the JSON API.
class WineProfilePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  def index? = true
  def show? = true
  def create? = user&.wine_manager?
  def update? = user&.wine_manager?
  def destroy? = user&.wine_manager?
end
