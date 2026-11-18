# frozen_string_literal: true

# Inbox access for the public Contact form (IDENTITY_209).
#
# Only global catalogue managers (Admin and Editor) may read the inbox.
# Readers and Reviewers are denied, and the controller enforces this
# independently of any menu visibility in the React app.
class ContactMessagePolicy < ApplicationPolicy
  def index? = manager?
  alias_method :show?, :index?
  alias_method :update?, :index?

  private

  def manager?
    user&.catalogue_manager? || false
  end
end
