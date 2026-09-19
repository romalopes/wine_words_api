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
    return WinePackage.all if current_user&.catalogue_manager?

    WinePackage.where(reviewer_id: current_user&.id)
               .or(WinePackage.where(created_by_id: current_user&.id))
  end

  def package_manageable?(package)
    return false if package.nil?

    current_user&.catalogue_manager? || package.reviewer_id == current_user&.id
  end

  # Any wine manager — Admins, Editors and Reviewers — may record a package.
  def ensure_package_creator!
    return if current_user&.wine_manager?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def ensure_package_manageable!
    return if package_manageable?(@package)

    render json: { error: "Forbidden" }, status: :forbidden
  end
end
