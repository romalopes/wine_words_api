# frozen_string_literal: true

# Authorization for Vintage records (nested under Wine).
#
# Any wine manager (Admin / Editor / Reviewer) may add vintages to a wine.
# Producer owners/managers may also manage vintages when the wine belongs to
# their linked producer. Contributors and unrelated readers remain read-only.
class VintagePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all
    end
  end

  def create? = user&.wine_manager? || producer_manager?
  def update? = user&.wine_manager? || producer_manager?
  def link_to_project? = user&.wine_manager?
  def destroy? = user&.catalogue_manager?

  private

  def producer_manager?
    producer_id = record&.wine&.producer_id
    return false unless user && producer_id

    ProducerMembership.where(
      user_id: user.id,
      producer_id: producer_id,
      membership_type: ProducerMembership::EDITABLE_TYPES
    ).exists?
  end
end
