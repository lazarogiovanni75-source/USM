class VoiceSetting < ApplicationRecord
  belongs_to :user
  
  validates :voice_id, presence: true
  validates :tone, presence: true
  validates :speed, numericality: { greater_than: 0, less_than_or_equal_to: 3.0 }
end