class Client < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :agency_user, class_name: 'User', optional: true, foreign_key: :agency_user_id
  
  has_many :campaigns, dependent: :nullify
  has_many :social_accounts, dependent: :nullify
  has_many :scheduled_posts, through: :campaigns
  
  validates :name, presence: true
  validates :status, inclusion: { in: %w[active inactive paused archived] }
  
  enum status: {
    active: 'active',
    inactive: 'inactive',
    paused: 'paused',
    archived: 'archived'
  }
  
  enum plan: {
    basic: 'basic',
    professional: 'professional',
    enterprise: 'enterprise'
  }
  
  scope :active_clients, -> { where(status: :active) }
  scope :by_plan, ->(plan) { where(plan: plan) }
  
  def total_campaigns
    campaigns.count
  end
  
  def active_campaigns
    campaigns.where(status: :running).count
  end
  
  def total_spent
    campaigns.sum(:budget).to_f
  end
end
