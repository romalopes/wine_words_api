# frozen_string_literal: true

class TasteParameterPolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve = scope.all
  end

  def index? = true
  def show? = true
  def create? = user&.wine_manager?
  def update? = user&.wine_manager?
  def destroy? = user&.wine_manager?
end
