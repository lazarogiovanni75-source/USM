class TrendAnalysis < ApplicationRecord
  belongs_to :user
  
  validates :analysis_type, presence: true
  validates :data, presence: true
end