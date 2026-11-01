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
  def index? = true
  def show? = true
  def update?
    return false unless user
    return true if user.wine_manager?

    record.producer_memberships
          .where(user_id: user.id, membership_type: ProducerMembership::EDITABLE_TYPES)
          .exists?
  end
  def link_wine? = user&.wine_manager?
  def link_to_project? = user&.wine_manager?
  alias_method :attach_logo?, :update?
  alias_method :remove_logo?, :update?
  def destroy? = user&.catalogue_manager?
end