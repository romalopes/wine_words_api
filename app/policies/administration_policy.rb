# frozen_string_literal: true

class AdministrationPolicy < ApplicationPolicy
  def access? = user&.admin?
  alias_method :configure?, :access?
  alias_method :view_logs?, :access?
  alias_method :diagnostics?, :access?
  alias_method :impersonate?, :access?
end