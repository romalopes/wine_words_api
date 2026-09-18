# Shared authorization for the wine-package endpoints.
#
# Ownership rule (one place, so every controller agrees):
#   * Admin/Editor (`wine_manager?`) may manage every package;
#   * otherwise a package is manageable only by its responsible reviewer
#     (`reviewer_id == current_user.id`).
#
# Recording a NEW package additionally allows the "Reviewer" role: the person
# who physically receives the wines is exactly who needs to log them. That is
# the only place the Reviewer role is accepted, and it never grants access to
# somebody else's package.
#
# Visibility follows the same shape: content managers see every package,
# everybody else sees only the ones they review or recorded.
module WinePackageAuthorizable
  extend ActiveSupport::Concern

  private

  def packages_scope
    return WinePackage.all if current_user&.wine_manager?

    WinePackage.where(reviewer_id: current_user&.id)
               .or(WinePackage.where(created_by_id: current_user&.id))
  end

  def package_manageable?(package)
    return false if package.nil?

    current_user&.wine_manager? || package.reviewer_id == current_user&.id
  end

  # Wine managers, or a Reviewer recording their own package.
  def ensure_package_creator!
    return if current_user&.wine_manager? || current_user&.reviewer?

    render json: { error: "Forbidden" }, status: :forbidden
  end

  def ensure_package_manageable!
    return if package_manageable?(@package)

    render json: { error: "Forbidden" }, status: :forbidden
  end
end
