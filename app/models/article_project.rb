class ArticleProject < ApplicationRecord
  PROJECT_STATUSES = %w[
    initiated planning pending_wines researching tasting final_draft
    pending_editor_review reviewed_by_editor published on_hold cancelled
  ].freeze
  DRAFTING_STATUSES = %w[not_initiated initiated in_progress finished].freeze

  belongs_to :created_by, class_name: "User"
  belongs_to :article, optional: true

  has_many :article_project_producers, dependent: :destroy
  has_many :producers, through: :article_project_producers
  has_many :article_project_vintages, dependent: :destroy
  has_many :vintages, through: :article_project_vintages
  has_many :article_project_reviews, dependent: :destroy
  has_many :reviews, through: :article_project_reviews

  accepts_nested_attributes_for :article_project_producers, :article_project_vintages, :article_project_reviews,
                                allow_destroy: true

  before_validation :normalize_name

  validates :name, presence: true, length: { maximum: 255 }
  validates :project_status, inclusion: { in: PROJECT_STATUSES }
  validates :drafting_status, inclusion: { in: DRAFTING_STATUSES }
  validates :editor_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :target_word_count, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :recent, -> { order(updated_at: :desc, id: :desc) }

  def overdue?
    deadline.present? && deadline < Date.current && !%w[published cancelled].include?(project_status)
  end

  def actual_word_count
    return nil unless article

    ArticleProjectWordCounter.count(article.body)
  end

  def word_count_remaining
    return nil if target_word_count.nil?
    return nil if actual_word_count.nil?

    target_word_count - actual_word_count
  end

  def vintage_counts
    rows = association(:article_project_vintages).loaded? ? article_project_vintages : article_project_vintages.to_a
    {
      total: rows.length,
      requested: rows.count(&:requested?),
      received: rows.count(&:received?),
      selected: rows.count(&:selected?),
      tasted: rows.count(&:tasted?)
    }
  end

  private

  def normalize_name
    self.name = name.to_s.strip.presence
  end
end