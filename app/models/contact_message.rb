# A message submitted through the public Contact form (IDENTITY_209).
#
# Visitors do not need an account, so there is no user association: the row
# carries only what is needed to respond (name, email, category, subject,
# body). Content is stored as plain text and must always be rendered escaped.
#
# Status is a single small state machine:
#
#   unread   -> read       stamps read_at
#   read     -> unread     clears read_at
#   any      -> archived   stamps archived_at
#   archived -> read/unread unarchives (archived_at cleared)
#
# Every transition is idempotent, so repeated clicks or retried requests are
# harmless.
class ContactMessage < ApplicationRecord
  # Stable API values. Labels live in the frontend constant and may change
  # without a migration; this list is the single source of truth for what the
  # public endpoint accepts.
  CONTACT_TYPES = %w[
    general
    wine_submission
    content
    business
    support
    feedback
    other
  ].freeze

  STATUSES = %w[unread read archived].freeze

  MAX_NAME_LENGTH = 120
  MAX_EMAIL_LENGTH = 254
  MAX_SUBJECT_LENGTH = 180
  MAX_MESSAGE_LENGTH = 10_000

  before_validation :normalize_attributes

  validates :name, presence: true, length: { maximum: MAX_NAME_LENGTH }
  validates :email,
            presence: true,
            length: { maximum: MAX_EMAIL_LENGTH },
            format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_type, presence: true, inclusion: { in: CONTACT_TYPES }
  validates :subject, presence: true, length: { maximum: MAX_SUBJECT_LENGTH }
  validates :message, presence: true, length: { maximum: MAX_MESSAGE_LENGTH }
  validates :status, presence: true, inclusion: { in: STATUSES }

  # Defence in depth: the format validation already rejects newlines, but a
  # dedicated check makes the e-mail-header-injection intent explicit.
  validate :email_has_no_header_injection

  scope :unread, -> { where(status: "unread") }
  scope :read, -> { where(status: "read") }
  scope :archived, -> { where(status: "archived") }
  # The unread badge only counts messages you can still act on.
  scope :not_archived, -> { where.not(status: "archived") }
  scope :by_recency, -> { order(created_at: :desc, id: :desc) }

  # Case-insensitive search over the fields the inbox exposes. Uses
  # sanitize_sql_like so a visitor's `%` is a literal, never a wildcard.
  def self.search(term)
    value = term.to_s.strip
    return all if value.empty?

    pattern = "%#{sanitize_sql_like(value.downcase)}%"
    where(
      "LOWER(name) LIKE :pattern OR LOWER(email) LIKE :pattern OR LOWER(subject) LIKE :pattern",
      pattern: pattern
    )
  end

  def unread?
    status == "unread"
  end

  def read?
    status == "read"
  end

  def archived?
    status == "archived"
  end

  # Idempotent status transition. Raises ArgumentError for an unsupported
  # value so callers can answer 422 instead of silently doing nothing.
  def apply_status!(next_status, at: Time.current)
    value = next_status.to_s
    raise ArgumentError, "unsupported status: #{value}" unless STATUSES.include?(value)

    case value
    when "read"
      return self if read?

      update!(status: "read", read_at: read_at || at, archived_at: nil)
    when "unread"
      return self if unread?

      update!(status: "unread", read_at: nil, archived_at: nil)
    when "archived"
      return self if archived?

      update!(status: "archived", archived_at: archived_at || at)
    end

    self
  end

  def mark_read!(at: Time.current)
    apply_status!("read", at: at)
  end

  def mark_unread!(at: Time.current)
    apply_status!("unread", at: at)
  end

  def archive!(at: Time.current)
    apply_status!("archived", at: at)
  end

  private

  def normalize_attributes
    self.name = name.to_s.strip
    self.email = email.to_s.strip.downcase
    self.contact_type = contact_type.to_s.strip.downcase
    self.subject = subject.to_s.strip
    self.message = message.to_s.strip
    self.status = status.to_s.strip.downcase
  end

  def email_has_no_header_injection
    return if email.blank?
    return unless email.match?(/[\r\n]/)

    errors.add(:email, "contains invalid characters")
  end
end
