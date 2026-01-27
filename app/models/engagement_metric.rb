class EngagementMetric < ApplicationRecord
  belongs_to :content
  
  validates :metric_type, presence: true
  validates :metric_value, presence: true
  validates :date, presence: true
end