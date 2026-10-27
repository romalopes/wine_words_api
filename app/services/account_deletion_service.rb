# Service object for account lifecycle operations: soft‑delete, reactivate,
# hard‑delete, and hard‑delete‑after‑grace‑period scheduling.
#
# All destructive operations acquire a row lock on the user inside a single
# transaction and re‑evaluate the deletion policy before committing so that
# concurrent changes cannot bypass the policy (TOCTOU protection).
class AccountDeletionService
  # Result object returned by every public method.
  Result = Struct.new(:success, :user, :error, :blocking_reasons, keyword_init: true) do
    def success?
      success
    end
  end

  class << self
    # Soft‑delete a user. Reversible.
    #
    # @param user [User]
    # @param actor [User] the admin performing the action (audit only)
    # @return [Result]
    def soft_delete(user, actor: nil)
      new(user, actor: actor).soft_delete!
    end

    # Reactivate a soft‑deleted user.
    #
    # @param user [User]
    # @param actor [User] the admin performing the action (audit only)
    # @return [Result]
    def reactivate(user, actor: nil)
      new(user, actor: actor).reactivate!
    end

    # Hard‑delete a user. Irreversible. Requires the feature flag
    # `hard_delete_enabled` to be true and no blocking dependencies.
    #
    # @param user [User]
    # @param actor [User] the admin performing the action (audit only)
    # @return [Result]
    def hard_delete(user, actor: nil)
      new(user, actor: actor).hard_delete!
    end

    # Schedule hard deletion after the 30‑day grace period.
    #
    # @param user [User]
    # @return [Result]
    def schedule_hard_delete(user)
      new(user).schedule_hard_delete!
    end
  end

  def initialize(user, actor: nil)
    @user = user
    @actor = actor
  end

  def soft_delete!
    return Result.new(success: false, user: @user, error: "already_deleted") unless transaction_soft_delete!

    Result.new(success: true, user: @user.reload)
  end

  def reactivate!
    return Result.new(success: false, user: @user, error: "not_deleted") unless transaction_reactivate!

    Result.new(success: true, user: @user.reload)
  end

  def hard_delete!
    return Result.new(success: false, user: @user, error: "hard_delete_disabled") unless AppSetting.hard_delete_enabled?
    return Result.new(success: false, user: @user, error: "already_deleted") if @user.deleted?

    policy = DeletionPolicy.new(@user)
    unless policy.hard_delete_allowed?
      return Result.new(
        success: false,
        user: @user,
        error: "blocked",
        blocking_reasons: policy.blocking_reasons
      )
    end

    begin
      transaction_hard_delete!
    rescue BlockedError => e
      # Concurrent write created a blocking dependency between the pre-check
      # and the transaction: fail closed, nothing was deleted.
      return Result.new(success: false, user: @user, error: "blocked",
                        blocking_reasons: e.blocking_reasons)
    end

    # The row is gone; do not reload.
    Result.new(success: true, user: @user)
  end

  def schedule_hard_delete!
    return Result.new(success: false, user: @user, error: "not_deleted") unless @user.deleted?

    DeleteUserJob.set(wait: 30.days).perform_later(@user.id)
    audit("scheduled_hard_delete", nil)
    Result.new(success: true, user: @user.reload)
  end

  private

  def transaction_soft_delete!
    return false if @user.deleted?

    scheduled = false
    @user.transaction do
      @user.lock!
      return false if @user.deleted?

      # Stamp and verify. The write deliberately goes through raw SQL
      # (`update_all`) instead of attribute assignment: a long-lived process
      # whose in-memory schema cache predates the `deleted_at` migration cannot
      # persist the attribute (its UPDATE silently degrades to updated_at-only,
      # as observed in dev). Raw SQL is immune to that process state. The
      # existence check is likewise SQL-based so verification cannot be fooled.
      stamp = Time.current
      Rails.logger.info(
        "[soft_delete] user_id=#{@user.id} column_known=#{@user.class.column_names.include?('deleted_at')} " \
        "reader=#{@user.respond_to?(:deleted_at)}"
      )
      updated = @user.class.where(id: @user.id).update_all(
        [ "deleted_at = ?, updated_at = ?", stamp, stamp ]
      )
      raise ActiveRecord::RecordNotSaved, "user #{@user.id} not found" unless updated == 1
      raise ActiveRecord::RecordNotSaved,
            "deleted_at was not persisted" unless @user.class.where(id: @user.id).where("deleted_at IS NOT NULL").exists?
      @user.reload
      revoke_sessions!
      audit("soft_delete", nil)
      scheduled = true
    end
    # After commit: schedule the 30-day hard-delete job. The job itself is
    # idempotent and re-checks both `deleted_at` and the feature flag.
    DeleteUserJob.set(wait: 30.days).perform_later(@user.id) if scheduled
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[AccountDeletionService] soft_delete failed for user #{@user.id}: #{e.message}")
    false
  end

  def transaction_reactivate!
    return false unless @user.deleted?

    @user.transaction do
      @user.lock!
      return false unless @user.deleted?

      # Mirror of the soft-delete stamp: raw SQL so the write does not depend on
      # the process's schema-cache state, with an SQL-level verification.
      updated = @user.class.where(id: @user.id).update_all(
        [ "deleted_at = NULL, updated_at = ?", Time.current ]
      )
      raise ActiveRecord::RecordNotSaved, "user #{@user.id} not found" unless updated == 1
      raise ActiveRecord::RecordNotSaved,
            "deleted_at was not cleared" if @user.class.where(id: @user.id).where("deleted_at IS NOT NULL").exists?
      @user.reload
      audit("reactivate", nil)
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("[AccountDeletionService] reactivate failed for user #{@user.id}: #{e.message}")
    false
  end

  def transaction_hard_delete!
    @user.transaction do
      @user.lock!

      # Re‑evaluate policy inside the transaction (TOCTOU protection).
      policy = DeletionPolicy.new(@user)
      raise BlockedError, policy.blocking_reasons unless policy.hard_delete_allowed?

      # Clean up disposable dependents inside the transaction.
      @user.likes.destroy_all
      @user.follows.destroy_all
      @user.notifications.destroy_all
      @user.notification_preference&.destroy
      @user.user_roles.destroy_all
      @user.user_identities.destroy_all
      @user.user_subscriptions.destroy_all
      @user.billing_customers.destroy_all

      # Protected / retained content: we never cascade‑delete reviews, articles,
      # comments, producer memberships, or financial records. Those are blocked
      # by the policy; if we reach here they should already be absent.

      # Finally destroy the user and its account.
      @user.account&.destroy!
      @user.destroy!
      audit("hard_delete", nil)
    end
  rescue BlockedError => e
    Rails.logger.error("[AccountDeletionService] hard_delete blocked for user #{@user.id}: #{e.message}")
    raise
  end

  def revoke_sessions!
    # Revoke the current JWT (exact-jti denylist entry). Broader server-side
    # enforcement of deleted accounts happens in
    # ApplicationController#reject_deleted_user!, which 403s every request
    # from a soft-deleted user regardless of token freshness.
    jti = @user.jwt_claims["jti"] if @user.respond_to?(:jwt_claims) && @user.jwt_claims
    JwtDenylist.create!(jti:, exp: Time.current + 1.week) if jti
  end

  def audit(action, objects)
    return unless defined?(LogService)

    LogService.log(
      description: "#{action.humanize} account #{@user.email} (id=#{@user.id})",
      action: action,
      user: @actor,
      objects: [ @user, @user.account ].compact
    )
  end

  # Raised when the policy blocks hard deletion inside a transaction.
  class BlockedError < StandardError
    attr_reader :blocking_reasons

    def initialize(blocking_reasons)
      @blocking_reasons = blocking_reasons
      super("Hard deletion blocked: #{blocking_reasons.map { |r| r[:message] }.join(', ')}")
    end
  end
end
