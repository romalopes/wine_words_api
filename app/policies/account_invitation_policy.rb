# frozen_string_literal: true

class AccountInvitationPolicy < ApplicationPolicy
  def index? = manageable_target?
  def create? = manageable_target?
  def resend? = manageable_target?
  def revoke? = manageable_target?

  private

  def manageable_target?
    return false unless user&.catalogue_manager?
    return true if user.admin?

    !record.roles.where(name: %w[Admin Editor]).exists?
  end
end
