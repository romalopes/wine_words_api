# Background job that performs a hard delete after the 30‑day grace period.
# Enqueued by AccountDeletionService#schedule_hard_delete! when a user is
# soft‑deleted. The job is idempotent: it does nothing if the user has already
# been hard‑deleted or reactivated, and it respects the
# `hard_delete_enabled` feature flag (disabled by default).
class DeleteUserJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user

    # Skip if reactivated or already hard‑deleted.
    return unless user.deleted?

    # Respect the feature flag even at job execution time.
    return unless AppSetting.hard_delete_enabled?

    result = AccountDeletionService.hard_delete(user)
    Rails.logger.info(
      "[DeleteUserJob] hard_delete user_id=#{user_id} " \
      "success=#{result.success?} error=#{result.error}"
    )
  end
end
