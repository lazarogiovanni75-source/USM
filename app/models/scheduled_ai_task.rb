class ScheduledAiTask < ApplicationRecord
  belongs_to :user
  
  validates :name, presence: true
  validates :task_type, presence: true
  validates :schedule_type, presence: true
  
  # Serialized fields
  serialize :config, JSON
  
  # Enums
  enum status: { active: 'active', inactive: 'inactive', paused: 'paused' }
  enum task_type: {
    content_generation: 'content_generation',
    performance_analysis: 'performance_analysis',
    trends_analysis: 'trends_analysis',
    ai_insights: 'ai_insights',
    content_optimization: 'content_optimization',
    engagement_analysis: 'engagement_analysis'
  }
  enum schedule_type: { once: 'once', daily: 'daily', weekly: 'weekly', monthly: 'monthly', quarterly: 'quarterly' }
  
  # Associations
  has_many :task_executions, dependent: :destroy
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_task_type, ->(type) { where(task_type: type) }
  scope :due, -> { active.where('next_run_at <= ?', Time.current) }
  
  # Default values
  before_validation :set_defaults, on: :create
  
  def active?
    status == 'active'
  end
  
  def recurring?
    schedule_type != 'once'
  end
  
  def next_execution_time
    service = ScheduledAiTasksService.new(@user)
    service.calculate_next_execution(self)
  end
  
  private
  
  def set_defaults
    self.status ||= 'active'
    self.config ||= {}
    self.next_run_at ||= Time.current + 1.hour
  end
end