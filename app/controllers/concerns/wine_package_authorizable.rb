# Shared authorization for the wine-package endpoints.
#
# Two tiers, mirroring User#catalogue_manager? and User#wine_manager?:
#   * Admin/Editor (`catalogue_manager?`) see and manage EVERY package;
#   * a Reviewer (or anyone else) is limited to the packages they are
#     responsible for (`reviewer_id == current_user.id`) or recorded, even
#     though Reviewers ARE wine managers for the rest of the catalogue.
#
# Recording a NEW package is open to any wine manager — which includes the
# Reviewer role, because the person who physically opens the box is exactly who
# needs to log it. That never grants access to somebody else's package.
#
# Visibility follows the same shape: catalogue managers see every package,
# everybody else sees only the ones they review or recorded (the `created_by`
# fallback matters because an admin can assign a package to a Reader, who must
# still be able to see it).
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

  def ensure_package_manageable!
    authorize @package, :manage?
  end
end
