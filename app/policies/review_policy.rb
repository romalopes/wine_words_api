# frozen_string_literal: true

# Authorization for Review records.
#
#   * Published reviews are publicly readable; drafts are only visible to
#     their author and to wine managers (Admin / Editor / Reviewer).
#   * Authoring is limited to wine managers; authors may edit their own
#     reviews, any wine manager may edit all.
#   * Destroying is reserved for catalogue managers (Admin / Editor).
class ReviewPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user&.wine_manager?
        scope.all
      elsif user
        # Non-wine managers: published reviews with score >= 85, OR score < 85 where user is author or producer member
        # Also include user's own reviews (any status)
        visible_published = scope.where(status: "published").where(
          "reviews.score >= 85 OR reviews.user_id = ? OR EXISTS (
            SELECT 1 FROM vintages v
            JOIN wines w ON w.id = v.wine_id
            JOIN producer_memberships pm ON pm.producer_id = w.producer_id
            WHERE v.id = reviews.vintage_id
              AND pm.user_id = ?
              AND pm.membership_type IN (?)
          )", user.id, user.id, ProducerMembership::MEMBERSHIP_TYPES
        )
        visible_published.or(scope.where(user: user))
      else
        # Not logged in: only score >= 85
        scope.where(status: "published").where("reviews.score >= 85")
      end
    end
  end

  def show? = record.status == "published" || record.user == user || user&.wine_manager?
  def index? = true

  def create? = user&.wine_manager?

  def update? = user&.wine_manager? || record.user == user

  def link_to_project? = user&.catalogue_manager? || record.user == user

  def destroy? = user&.catalogue_manager?
end
