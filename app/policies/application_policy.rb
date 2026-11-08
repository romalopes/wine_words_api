# frozen_string_literal: true

# Base policy for Pundit authorization. All policy classes inherit from here.
class ApplicationPolicy
  # Pundit calls ApplicationPolicy.new(user, record) - both arguments are required.
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Default policy - denies everything unless explicitly allowed.
  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false

  # Scope class - used as the base for policy Scope classes in child policies.
  # Child policies should declare `class Scope < ApplicationPolicy::Scope`
  # (or simply `class Scope < Scope`, which resolves to the same class).
  class Scope
    attr_reader :user, :scope

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    # Secure default: resources without an explicit scope expose no records.
    def resolve
      scope.none
    end
  end
end
