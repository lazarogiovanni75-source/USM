class ResponseTemplate < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :body, presence: true
  
  # Enums
  enum category: { 
    greeting: 'greeting',
    thank_you: 'thank_you',
    response: 'response',
    professional: 'professional',
    casual: 'casual',
    custom: 'custom'
  }
  
  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :active, -> { where(active: true) }
  
  # Default values
  before_validation :set_defaults, on: :create
  
  def active?
    active == true
  end
  
  private
  
  def set_defaults
    self.active ||= true
    self.category ||= 'custom'
  end
end