# Shared authorization for the wine-package endpoints.
#
# Tiers, mirroring User#catalogue_manager? / User#wine_manager? and the
# ProducerMembership management predicate (issue #199):
#   * Admin/Editor (`catalogue_manager?`) see and manage EVERY package;
#   * a Reviewer (or anyone else) is limited to the packages they are
#     responsible for (`reviewer_id == current_user.id`) or recorded, even
#     though Reviewers ARE wine managers for the rest of the catalogue;
#   * an owner/manager member of a producer may see and manage packages for
#     their producer only, and only in producer-editable stages (draft fields,
#     draft items/attachments, shipment details after acceptance). A follower
#     or contributor never qualifies.
#
# Recording a NEW package is open to any wine manager — which includes the
# Reviewer role, because the person who physically opens the box is exactly who
# needs to log it. That never grants access to somebody else's package.
#
# Visibility follows the same shape: catalogue managers see every package,
# everybody else sees only the ones they review, recorded or manage as a
# producer member.
module WinePackageAuthorizable
  extend ActiveSupport::Concern

  private

  def packages_scope
    policy_scope(WinePackage)
  end

  def package_manageable?(package)
    return false if package.nil?

    WinePackagePolicy.new(current_user, package).update?
  end

  # Any wine manager — Admins, Editors and Reviewers — may record a package.
  def ensure_package_creator!
    authorize WinePackage, :create?
  end

  # Workflow actions (accept/reject/receipt/transitions/destroy) stay
  # editorial-only — a producer member can never drive the editorial workflow.
  def ensure_package_manageable!
    authorize @package, :manage?
  end

  # Field edits (draft details) — producer members may edit their own drafts.
  def ensure_package_editable!
    authorize @package, :update?
  end

  # Nested wine lines — producers only while the request is still a draft.
  def ensure_package_items_manageable!
    authorize @package, :manage_items?
  end

  # Attachments — producers while the package is in producer-editable stages.
  def ensure_package_attachments_manageable!
    authorize @package, :manage_attachments?
  end

  # Shipment details — producers only after acceptance (or while announcing).
  def ensure_package_tracking_manageable!
    authorize @package, :manage_tracking?
  end

  # Review creation (`create_review` on an item) stays editorial.
  def ensure_package_editorial_manageable!
    authorize @package, :review?
  end

  # Withdrawing a pending producer request — the producer side or the editorial
  # side (issue #199 §2: "Withdraw pending request: Conditional").
  def ensure_package_withdrawable!
    authorize @package, :withdraw?
  end
end
