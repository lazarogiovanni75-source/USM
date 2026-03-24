# frozen_string_literal: true

# Model for storing Postforme post analytics
# Replaces BufferAnalytic
class PostformeAnalytic < ApplicationRecord
  belongs_to :scheduled_post

  validates :postforme_post_id, presence: true

  scope :by_date_range, ->(start_date, end_date) {
    where(created_at: start_date..end_date) if start_date.present? && end_date.present?
  }

  def total_engagement
    [likes.to_i, comments.to_i, shares.to_i].sum
  end

  def engagement_rate
    return 0 if impressions.to_i.zero?

    (total_engagement.to_f / impressions.to_i * 100).round(2)
  end
end
