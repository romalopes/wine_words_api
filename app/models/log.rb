class Log < ApplicationRecord
  # Append-only audit record: no updates or deletions through the app.
  attr_readonly :description, :user_id, :action, :method, :path, :status,
                :request_id, :ip_address, :user_agent

  belongs_to :user, optional: true
  has_many :log_objects, dependent: :destroy
  has_many :objects, through: :log_objects

  validates :description, presence: true
  validates :action, presence: true

  # Historical display for an object that may have been deleted since.
  # Prefers the label snapshot taken at log time; falls back to the live record.
  def object_labels
    log_objects.includes(:object).map do |log_object|
      obj = log_object.object
      {
        type: log_object.object_type,
        id: log_object.object_id,
        label: log_object.object_label.presence || obj&.try(:name) || obj&.try(:user_name) || obj&.try(:email),
        alive: obj.present?
      }
    end
  end
end
