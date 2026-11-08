# frozen_string_literal: true

class AnalyticsPolicy < ApplicationPolicy
  def report?
    user.present? && (user.reviewer? || user.role?(:editor) || user.admin?)
  end
end
