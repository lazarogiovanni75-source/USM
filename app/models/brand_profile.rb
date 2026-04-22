class BrandProfile < ApplicationRecord
  belongs_to :user
  
  CONTENT_TONES = %w[professional casual humorous inspirational].freeze
  INDUSTRIES = %w[E-commerce Technology Healthcare Finance Food\ Beverage Travel Education Real\ Estate Fashion Entertainment Marketing Other].freeze
  
  validates :content_tone, inclusion: { in: CONTENT_TONES }, allow_blank: true
  
  scope :incomplete, -> { where(onboarding_completed: false) }
  scope :dismissed_recently, -> { where("onboarding_dismissed_at > ?", 3.days.ago) }
  
  def onboarding_incomplete?
    !onboarding_completed
  end
  
  def needs_onboarding_reminder?
    onboarding_incomplete? && (onboarding_dismissed_at.nil? || onboarding_dismissed_at < 3.days.ago)
  end
  
  def next_onboarding_step
    onboarding_step.to_i
  end
  
  def advance_onboarding_step!
    increment!(:onboarding_step)
  end
  
  def complete_onboarding!
    update(onboarding_completed: true, onboarding_step: 99)
  end
  
  def dismiss_onboarding
    update(onboarding_dismissed_at: Time.current)
  end
  
  def resume_onboarding
    update(onboarding_dismissed_at: nil)
  end
  
  def industry_options
    %w[Marketing E-commerce Restaurant Fitness Real Estate Beauty Technology Other]
  end
  
  def self.get_or_create_for(user)
    find_or_create_by(user: user)
  end
end
