# frozen_string_literal: true

class PostMetric < ApplicationRecord
  belongs_to :post, polymorphic: true
  belongs_to :social_account, optional: true

  validates :platform, presence: true
  validates :collected_at, presence: true

  # Convenience scopes
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :recent, -> { order(collected_at: :desc) }
  scope :since, ->(time) { where('collected_at >= ?', time) }

  # Calculate engagement rate from metrics
  def calculate_engagement_rate
    return 0.0 if impressions.to_i.zero?
    ((likes.to_i + comments.to_i + shares.to_i + saves.to_i).to_f / impressions.to_i * 100).round(2)
  end

  # Calculate CTR
  def calculate_ctr
    return 0.0 if impressions.to_i.zero?
    ((clicks.to_i.to_f / impressions.to_i) * 100).round(2)
  end

  # Update aggregated metrics
  after_save :update_aggregates, if: :saved_change_to_impressions?

  private

  def update_aggregates
    # Could trigger cache invalidation or denormalization here
  end
end
