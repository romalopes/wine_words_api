# frozen_string_literal: true

class SubscriptionPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.active.visible
    end
  end

  def index? = true
  def show? = user&.admin?
  def create? = user&.admin?
  def update? = user&.admin?
  def destroy? = user&.admin?
end