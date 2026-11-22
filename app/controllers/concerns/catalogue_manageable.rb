# Shared write-authorization for server-rendered catalogue/taxonomy scaffold
# controllers (wine profiles, taste parameters, test parameters, wine taste
# parameters).
#
# Reads (index/show) stay public — matching the JSON API equivalent — but any
# mutation requires a wine manager (Admin / Editor / Reviewer), the same rule
# as TasteParameterPolicy#create?/update?/destroy?. This closes the
# previously-unauthenticated web CRUD found by the security audit (issue #23).
module CatalogueManageable
  extend ActiveSupport::Concern

  private

  def can_manage_catalogue?
    user_signed_in? && current_user.wine_manager?
  end

  def deny_unless_catalogue_manager!
    return if can_manage_catalogue?

    redirect_to(root_path, alert: "You are not allowed to manage the catalogue.")
    false
  end
end
