# Centralized audit-log service.
#
#   LogService.log(
#     description: 'Updated wine "Grange 2021"',
#     user: current_user,
#     action: "update",
#     objects: [wine, wine.producer]
#   )
#
# Request metadata (method/path/status/request_id/ip/user_agent) is filled
# automatically by the Auditable controller concern; it can also be passed
# explicitly for non-request contexts (background jobs, console, seeds).
#
# Guarantees:
#   * NEVER raises — a logging failure must not fail the business operation.
#     Failures are reported via Rails.logger.error so they can be diagnosed.
#   * NEVER stores secrets — only whitelisted scalar metadata is persisted.
#   * Supports anonymous/system operations (user: nil).
class LogService
  MAX_TEXT_LENGTH = 2048

  class << self
    def log(description:, action:, user: nil, method: nil, path: nil,
            status: nil, request_id: nil, ip_address: nil, user_agent: nil,
            objects: [])
      log_record = Log.create!(
        description: sanitize(description),
        user: user,
        action: sanitize(action),
        method: sanitize(method, limit: 16),
        path: sanitize(path),
        status: status.is_a?(Integer) ? status : nil,
        request_id: sanitize(request_id, limit: 64),
        ip_address: sanitize(ip_address, limit: 64),
        user_agent: sanitize(user_agent)
      )

      attach_objects(log_record, objects)
      log_record
    rescue StandardError => e
      # Logging must never break the original operation. Report separately.
      Rails.logger.error(
        "[audit] failed to write log (action=#{action.inspect}): " \
        "#{e.class}: #{e.message}"
      )
      nil
    end

    private

    def sanitize(value, limit: MAX_TEXT_LENGTH)
      return nil if value.blank?

      value.to_s[0, limit]
    end

    # Accepts ActiveRecord records and [Class_or_String, id, label] triples
    # (the latter for objects already deleted at log time).
    def attach_objects(log_record, objects)
      Array(objects).compact.each do |object|
        log_object =
          if object.is_a?(ActiveRecord::Base)
            { object: object, object_label: label_for(object) }
          elsif object.is_a?(Array) && object.length >= 2
            type, id, label = object
            { object_type: type.to_s, object_id: id, object_label: label }
          else
            next
          end

        log_record.log_objects.create!(log_object)
      rescue StandardError => e
        # A single bad object reference must not lose the whole log entry.
        Rails.logger.error("[audit] failed to attach log object: #{e.class}: #{e.message}")
      end
    end

    def label_for(record)
      record.try(:name) || record.try(:user_name) || record.try(:email) ||
        "#{record.class.model_name.human} ##{record.id}"
    end
  end
end
