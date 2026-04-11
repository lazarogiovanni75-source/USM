class Workflow < ApplicationRecord
  belongs_to :user

  validates :workflow_type, presence: true
  validates :content, presence: true
  before_validation :set_title, if: -> { content.present? && title.blank? }

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, prefix: true

  private

  def set_title
    self.title = content.truncate(50)
  end
end
