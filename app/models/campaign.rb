class Campaign < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true
  
  has_many :contents, dependent: :nullify
  has_many :scheduled_posts, through: :contents
  has_many :social_accounts_campaigns, dependent: :destroy
  has_many :social_accounts, through: :social_accounts_campaigns
  has_many :tasks, class_name: 'CampaignTask', dependent: :destroy
  
  validates :name, presence: true
  validates :status, presence: true
  
  # Integer-based enum for orchestration states
  enum status: {
    draft: 0,
    planning: 1,
    scheduled: 2,
    running: 3,
    paused: 4,
    completed: 5,
    failed: 6
  }
  
  enum goal: { awareness: 'awareness', engagement: 'engagement', conversions: 'conversions', traffic: 'traffic', followers: 'followers' }
  enum campaign_type: { product_launch: 'product_launch', seasonal: 'seasonal', brand_awareness: 'brand_awareness', lead_generation: 'lead_generation', community_building: 'community_building', content_promo: 'content_promo', event_promo: 'event_promo', user_generated: 'user_generated' }
  
  scope :recent, -> { order(created_at: :desc) }
  scope :active_campaigns, -> { where(status: :running) }
  scope :by_status, ->(status) { where(status: status) }
  scope :search, ->(query) { where("name ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%") }
  scope :current, -> { where("start_date <= ? AND end_date >= ?", Date.current, Date.current) }
  
  serialize :platforms, Array
  serialize :content_pillars, Array
  serialize :hashtag_set, Array
  serialize :mentions, Array
  serialize :kpis, Array
  
  before_validation :set_defaults, on: :create
  before_validation :normalize_status
  
  after_update_commit :broadcast_status
  
  def normalize_status
    return unless status.present?
    # Convert string status to integer for backward compatibility
    if status.is_a?(String) && status.match?(/^\d+$/)
      self.status = status.to_i
    elsif status.is_a?(String)
      status_map = { 'draft' => 0, 'planning' => 1, 'scheduled' => 2, 'running' => 3, 'active' => 3, 'paused' => 4, 'completed' => 5, 'failed' => 6 }
      self.status = status_map[status] || 0
    end
  end
  
  # Campaign orchestration methods
  def start!
    update!(status: :planning, started_at: Time.current)
    Ai::Orchestrator.plan_campaign(self)
  rescue => e
    fail!
    Rails.logger.error "[Campaign] Failed to start campaign #{id}: #{e.message}"
  end
  
  def mark_completed!
    update!(status: :completed, completed_at: Time.current)
  end
  
  def mark_paused!
    update!(status: :paused)
  end
  
  def resume!
    update!(status: :running)
    Ai::Orchestrator.enqueue_tasks(self)
  end
  
  def fail!
    update!(status: :failed)
  end

  # Aliases for backward compatibility
  alias_method :active?, :running?
  alias_method :mark_active!, :resume!
  
  def duration_days
    return 0 unless start_date && end_date
    (end_date - start_date).to_i + 1
  end
  
  def progress_percentage
    return 0 unless start_date && end_date
    total_days = duration_days
    elapsed = (Date.current - start_date).to_i + 1
    [(elapsed.to_f / total_days * 100).round(2), 100].min
  end
  
  def budget_spent
    scheduled_posts.published.sum(:cost) || 0
  end
  
  def budget_remaining
    (budget || 0) - budget_spent
  end
  
  def content_progress
    return 0 unless content_count.to_i > 0
    (contents.published.count.to_f / content_count * 100).round(2)
  end
  
  def engagement_rate
    return 0 unless scheduled_posts.published.any?
    total_engagements = scheduled_posts.published.joins(:performance_metrics).sum(:likes) +
                        scheduled_posts.published.joins(:performance_metrics).sum(:comments) +
                        scheduled_posts.published.joins(:performance_metrics).sum(:shares)
    total_views = scheduled_posts.published.joins(:performance_metrics).sum(:views)
    return 0 if total_views == 0
    (total_engagements.to_f / total_views * 100).round(2)
  end
  
  def duplicate
    new_campaign = user.campaigns.build(
      name: "#{name} (Copy)",
      description: description,
      target_audience: target_audience,
      budget: budget,
      start_date: Date.current,
      end_date: Date.current + duration_days.days,
      status: 'draft',
      goal: goal,
      goal_value: goal_value,
      platforms: platforms,
      content_count: content_count,
      hashtag_set: hashtag_set,
      mentions: mentions,
      campaign_type: campaign_type,
      content_pillars: content_pillars
    )
    
    new_campaign.save
    new_campaign
  end
  
  def generate_content_ideas(ai_service, count = 5)
    prompt = "Generate #{count} content ideas for a social media campaign with the following details:
    - Campaign Name: #{name}
    - Description: #{description}
    - Target Audience: #{target_audience}
    - Platforms: #{platforms.join(', ')}
    - Content Pillars: #{content_pillars.join(', ')}
    
    Return the ideas as a JSON array with objects containing: title, content_type, platform, hashtags, description"
    
    response = ai_service.generate_response(prompt)
    if response[:success]
      JSON.parse(response[:response])
    else
      []
    end
  end
  
  private
  
  def set_defaults
    self.status ||= 0  # draft as integer
    self.start_date ||= Date.current
    self.end_date ||= Date.current + 30.days
    self.platforms ||= []
    self.content_pillars ||= []
    self.hashtag_set ||= []
    self.mentions ||= []
  end
  
  def broadcast_status
    ActionCable.server.broadcast("campaign_#{id}", { status: status }) if saved_change_to_status?
  end
end
