# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  def create? = user&.catalogue_manager?
  def search? = user&.catalogue_manager?
  def roles? = user&.catalogue_manager?
  def show? = user&.catalogue_manager?
  def invitation_email? = manageable_target?
  def assign_roles? = user&.admin?
  def assign_subscription? = user&.admin?
  def soft_delete? = user&.admin?
  def hard_delete? = user&.admin?
  def reactivate? = user&.admin?
  def update_account? = user&.admin?

  private

  def manageable_target?
    return false unless user&.catalogue_manager?
    return true if user.admin?

    !record.roles.where(name: %w[Admin Editor]).exists?
  end
end
