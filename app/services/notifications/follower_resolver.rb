# frozen_string_literal: true

# Resolves the distinct set of Users who follow any of an event's affected
# targets and are eligible for a delivery:
#
#   * the Follow must have existed when the event occurred
#     (follows created after the event do not receive it);
#   * the actor is always excluded;
#   * duplicates from inherited coverage (follow Review + Wine + Producer)
#     collapse to one recipient per event.
#
# Set-based SQL: one query per event, no per-follower lookups.
module Notifications
  class FollowerResolver
    def initialize(event)
      @event = event
    end

    # Returns a flat list of user ids, actor excluded, deduplicated.
    def resolve
      scope = nil

      @event.targets.each do |target|
        match = Follow.where(followable_type: target[:type], followable_id: target[:id])
        scope = scope ? scope.or(match) : match
      end

      return [] if scope.nil?

      scope = scope.where("follows.created_at <= ?", @event.occurred_at)
      scope = scope.where.not(user_id: @event.actor_id) if @event.actor_id

      scope.distinct.pluck(:user_id)
    end
  end
end