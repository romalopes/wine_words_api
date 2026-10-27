# Structured policy for evaluating whether a user may be hard‑deleted.
#
# Returns a report with:
#   * hard_delete_allowed? — boolean
#   * blocking_reasons — array of hashes {code, count, message}
#   * disposable_counts — hash of association name => count
class DeletionPolicy
  BLOCKING_ASSOCIATIONS = %i[
    reviews
    comments
    producer_memberships
    subscription_changes
    billing_customers
  ].freeze

  DISPOSABLE_ASSOCIATIONS = %i[
    likes
    follows
    notifications
    user_roles
    user_identities
    user_subscriptions
  ].freeze

  def initialize(user)
    @user = user
  end

  def hard_delete_allowed?
    blocking_reasons.empty?
  end

  def blocking_reasons
    @blocking_reasons ||= compute_blocking_reasons
  end

  def disposable_counts
    @disposable_counts ||= compute_disposable_counts
  end

  private

  def compute_blocking_reasons
    reasons = []

    # Authored content blocks hard deletion initially: reviews and comments are
    # direct associations; articles only exist as an inverse `belongs_to`, so
    # they are counted with a direct query.
    content_checks = {
      "published_reviews" => @user.reviews,
      "comments" => @user.comments,
      "articles" => Article.where(user_id: @user.id)
    }
    content_checks.each do |code, relation|
      count = relation.count
      next if count.zero?

      reasons << {
        code: code,
        count: count,
        message: "#{count} #{code.to_s.humanize.downcase} authored by this user"
      }
    end

    # Producer memberships / ownership block hard deletion.
    pm_count = @user.producer_memberships.count
    if pm_count.positive?
      reasons << { code: "producer_memberships", count: pm_count,
                   message: "#{pm_count} producer membership#{pm_count == 1 ? '' : 's'}" }
    end

    # Billing history / subscription changes are financial records.
    sub_count = @user.subscription_changes.count
    if sub_count.positive?
      reasons << { code: "subscription_changes", count: sub_count,
                   message: "#{sub_count} subscription change#{sub_count == 1 ? '' : 's'}" }
    end

    billing_count = @user.billing_customers.count
    if billing_count.positive?
      reasons << { code: "billing_customers", count: billing_count,
                   message: "#{billing_count} billing record#{billing_count == 1 ? '' : 's'}" }
    end

    # Last active administrator protection: deleting the final admin would lock
    # out administration, so block when no *other* admin would remain.
    if @user.admin? && admin_count_excluding_user.zero?
      reasons << { code: "last_admin", count: 1, message: "user is the last active administrator" }
    end

    reasons
  end

  def admin_count_excluding_user
    @admin_count_excluding_user ||=
      User.joins(:roles).where(roles: { name: Role.names[:admin] }).where.not(id: @user.id).count
  end

  def compute_disposable_counts
    DISPOSABLE_ASSOCIATIONS.each_with_object({}) do |assoc, hash|
      hash[assoc] = @user.public_send(assoc).count
    end
  end
end
