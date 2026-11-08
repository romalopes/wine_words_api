# frozen_string_literal: true

class ProducerMembershipPolicy < ApplicationPolicy
  def index? = user&.catalogue_manager?
  def index_for_producer? = user&.wine_manager?
  def create? = user&.catalogue_manager?
  def update? = user&.catalogue_manager?
  def destroy? = user&.catalogue_manager?
end
