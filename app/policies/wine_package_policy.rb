# frozen_string_literal: true

# Pundit policy for Wine Packages (issue #199).
#
# Four tiers, mirroring User#catalogue_manager? / User#wine_manager? and the
# ProducerMembership management predicate:
#   * Admin/Editor (`catalogue_manager?`) see and manage EVERY package;
#   * a Reviewer (or anyone else) is limited to the packages they are
#     responsible for (`reviewer_id == current_user.id`) or recorded;
#   * an ACTIVE owner/manager member of a producer may see packages for that
#     producer and manage them only in producer-editable stages (draft fields,
#     draft items/attachments, shipment details after acceptance) — never the
#     editorial workflow (accept/reject/receipt/publication);
#   * followers and contributors never qualify.
class WinePackagePolicy < ApplicationPolicy
  # Producer members manage packages only while the package is in a stage they
  # own: before submission (draft) or while shipping details are still
  # correctable (announced/accepted/in_transit). Once arrived, everything is
  # editorial.
  PRODUCER_MANAGEABLE_STATUSES = %w[draft announced accepted in_transit].freeze

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.catalogue_manager?
      return scope.none unless user

      own = scope.where(reviewer_id: user.id).or(scope.where(created_by_id: user.id))
      own.or(scope.where(producer_id: ProducerMembership.managing_producer_ids_for(user)))
    end
  end

  def index? = user.present?

  def show?
    editorial_manage? || created_by? || producer_member?
  end

  # Recording a package: any wine manager (Admin/Editor/Reviewer) may record a
  # package for any producer; an owner/manager member may open a
  # producer-managed draft for THEIR producer only.
  def create?
    user&.wine_manager? || producer_member?
  end

  # Package *fields*: producers may edit only their own draft; editors, admins
  # and the assigned reviewer keep their existing rights.
  def update?
    editorial_manage? || (producer_member? && record.draft?)
  end

  # Deleting a package stays editorial-only — never a producer action (§2).
  def destroy?
    editorial_manage?
  end

  # Workflow actions (accept/reject/receipt/transitions/destroy) are
  # editorial-only — a producer member can never drive the editorial workflow.
  def manage?
    editorial_manage?
  end

  # Nested wine lines: producers may add/edit/remove lines only while the
  # request is still a draft.
  def manage_items?
    editorial_manage? || (producer_member? && record.draft?)
  end

  # Attachments (photos/documents): producers may upload/remove SHARED files
  # while the package is in producer-editable stages; editors manage all.
  def manage_attachments?
    editorial_manage? || (producer_member? && PRODUCER_MANAGEABLE_STATUSES.include?(record.status))
  end

  # Shipment details: producers may add/update tracking only after their
  # request has been accepted (or while announcing an expected shipment), and
  # never alter provider event history.
  def manage_tracking?
    editorial_manage? || (producer_member? && PRODUCER_MANAGEABLE_STATUSES.include?(record.status))
  end

  # Carrier/provider refreshes can append provider events and update the
  # editorial shipment snapshot, so they remain editorial-only.
  def refresh_tracking?
    editorial_manage?
  end

  # Submitting a producer draft for review.
  def submit?
    editorial_manage? || (producer_member? && record.draft?)
  end

  # Withdrawing a pending request: the producer side or the editorial side.
  def withdraw?
    editorial_manage? || (producer_member? && record.requested?)
  end

  # A withdrawn producer request may be corrected and resubmitted. Editorial
  # users may also restore it when handling a producer support request.
  def restore_draft?
    record.cancelled? && (editorial_manage? || producer_member?)
  end

  def accept?
    editorial_manage? && record.requested?
  end

  def reject?
    editorial_manage? && record.requested?
  end

  def mark_in_transit?
    editorial_manage? && record.can_transition_to?("in_transit")
  end

  def mark_arrived?
    editorial_manage? && record.can_transition_to?("arrived")
  end

  def start_reviewing?
    editorial_manage? && record.can_transition_to?("reviewing") && !record.completed?
  end

  def mark_completed?
    editorial_manage? && record.can_transition_to?("completed")
  end

  def reopen?
    editorial_manage? && record.completed? && record.can_transition_to?("reviewing")
  end

  def cancel?
    editorial_manage? && record.can_transition_to?("cancelled")
  end

  # Starting/completing reviews (`create_review` on an item) stays editorial.
  def review?
    editorial_manage?
  end

  # Exposed for controllers that need to branch parameter sets by viewer kind.
  def producer_member? = producer_membership_exists?

  # Exposed for controllers/serializers: the caller is on the editorial side
  # (catalogue manager or the package's reviewer) and may see editorial-only
  # fields. Note `show?` is broader — created_by users and producer members can
  # view the producer-safe projection too.
  def editorial_viewer? = editorial_manage?

  private

  def editorial_manage?
    user&.catalogue_manager? || record.reviewer_id == user&.id
  end

  def created_by?
    user && record.created_by_id == user.id
  end

  def producer_membership_exists?
    return false unless user && record.respond_to?(:producer_id) && record.producer_id

    ProducerMembership.where(
      user_id: user.id,
      producer_id: record.producer_id,
      membership_type: ProducerMembership::EDITABLE_TYPES
    ).exists?
  end
end
