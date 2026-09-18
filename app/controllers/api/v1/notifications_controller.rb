# The signed-in user's notifications (deadline reminders today, in-app list
# later). Notifications are created by the scheduling service and delivered by
# the recurring job; this controller only reads them and marks them read.
class Api::V1::NotificationsController < ApplicationController
  audit_actions mark_read: "notification.read", mark_all_read: "notification.read_all"

  before_action :set_notification, only: [ :mark_read ]

  def log_description
    "Marked notification ##{@notification&.id} as read"
  end

  def log_objects
    [ @notification, @notification&.wine_package ].compact
  end

  # GET /api/v1/notifications?unread=true&page=1
  def index
    notifications = current_user.notifications
                                .includes(wine_package: :producer)
                                .by_recency

    notifications = notifications.unread if params[:unread] == "true"
    notifications = notifications.for_date(params[:date]) if params[:date].present?
    notifications = notifications.where(notification_type: params[:type]) if params[:type].present?

    return if render_paginated(notifications) { |items| serialize_notifications(items) }

    render json: serialize_notifications(notifications)
  end

  # PATCH /api/v1/notifications/:id/mark_read
  def mark_read
    @notification.mark_read!
    render json: NotificationSerializer.new(@notification, request.base_url).as_json
  end

  # PATCH /api/v1/notifications/mark_all_read
  def mark_all_read
    marked = current_user.notifications.unread.update_all(read_at: Time.current)

    render json: { marked: marked }
  end

  private

  def serialize_notifications(notifications)
    notifications.map { |n| NotificationSerializer.new(n, request.base_url).as_json }
  end

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Notification not found" }, status: :not_found
  end
end
