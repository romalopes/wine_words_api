# frozen_string_literal: true

# Authorization for Wine records.
#
# Mirrors the app's role model (see User):
#   * wine_manager? (Admin / Editor / Reviewer) may create and edit wines;
#   * producer owners/managers may create and edit wines belonging to their
#     linked producer;
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
  def index? = true

  def create? = user&.wine_manager? || producer_manager?

  def update? = user&.wine_manager? || producer_manager?

  def destroy? = user&.catalogue_manager?

  private

  def producer_manager?
    return false unless user && record.respond_to?(:producer_id) && record.producer_id

    ProducerMembership.where(
      user_id: user.id,
      producer_id: record.producer_id,
      membership_type: ProducerMembership::EDITABLE_TYPES
    ).exists?
  end
end