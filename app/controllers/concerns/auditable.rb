# Centralized request auditing.
#
# Controllers declare which actions are audit-worthy; everything else is left
# unlogged so ordinary read requests do not generate noise:
#
#   class Api::V1::WinesController < ApplicationController
#     audit_actions :create, :update, :destroy
#
#     def log_description              # optional, human-readable description
#       "Created wine \"#{@wine.name}\""
#     end
#
#     def log_objects                  # optional, affected domain objects
#       [@wine, @wine.producer]
#     end
#   end
#
# The concern fires in after_action so the response status is known, and
# delegates persistence to LogService (which never raises).
module Auditable
  extend ActiveSupport::Concern

  included do
    class_attribute :audited_actions, instance_writer: false
    self.audited_actions = [].freeze

    after_action :write_audit_log, if: :audit_this_action?
  end

  class_methods do
    # audit_actions :create, :update
    # audit_actions login: "authentication"   # custom action name
    def audit_actions(*actions)
      mapped = actions.map { |a| a.is_a?(Hash) ? a : [a.to_s, a.to_s] }.to_h
      self.audited_actions = (audited_actions || {}).merge(
        mapped.transform_keys(&:to_s)
      ).freeze
    end
  end

  private

  def audit_this_action?
    return false if response.status >= 500 # server errors are not business audits

    (audited_actions || {}).key?(action_name)
  end

  def audit_action_name
    (audited_actions || {})[action_name] || action_name
  end

  # Human verb for the common CRUD actions ("Created"/"Updated"/"Deleted").
  def audit_verb
    { "create" => "Created", "update" => "Updated",
      "destroy" => "Deleted" }[action_name] || action_name.humanize
  end

  def write_audit_log
    LogService.log(
      description: (log_description if respond_to?(:log_description, true)) ||
                   "#{audited_actions[action_name]} #{action_name}",
      user: respond_to?(:current_user, true) ? current_user : nil,
      action: audit_action_name,
      method: request.request_method,
      path: request.path,
      status: response.status,
      request_id: request.request_id,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      objects: (respond_to?(:log_objects, true) ? log_objects : [])
    )
  end
end
