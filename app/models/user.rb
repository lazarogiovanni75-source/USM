class User < ApplicationRecord
  MIN_PASSWORD = 4
  GENERATED_EMAIL_SUFFIX = "@generated-mail.ultimate-social-media.com"

  has_secure_password validations: false

  # Strategy History
  has_many :strategy_histories, dependent: :destroy

  # Agency Staff Roles
  AGENCY_ROLES = %w[admin editor viewer].freeze
  validates :agency_role, inclusion: { in: AGENCY_ROLES }, if: -> { agency_role.present? }

  # Agency-related associations
  has_many :clients, dependent: :nullify
  has_many :agency_staff_clients, class_name: 'Client', foreign_key: :agency_user_id, dependent: :nullify

  # Helper methods for agency roles
  def agency_admin? = agency_role == 'admin'
  def agency_editor? = agency_role == 'editor'
  def agency_viewer? = agency_role == 'viewer'
  def agency_staff? = agency_role.present?
  
  def can_manage_clients?
    agency_admin? || agency_editor?
  end

  # Role-based Access Control (existing)
  ROLES = %w[user premium moderator admin].freeze
  validates :role, inclusion: { in: ROLES }, if: -> { role.present? }
  
  # Subscription Plans
  SUBSCRIPTION_PLANS = %w[Starter Entrepreneur Pro].freeze
  validates :subscription_plan, inclusion: { in: SUBSCRIPTION_PLANS }, if: -> { subscription_plan.present? }
  
  # Helper methods
  def pro? = subscription_plan == 'Pro'
  def entrepreneur? = subscription_plan == 'Entrepreneur'
  def starter? = subscription_plan == 'Starter'
  def paid_plan? = subscription_plan.present?
  
  # Plan Limits Configuration
  PLAN_LIMITS = {
    'Starter' => {
      max_platforms: 3,
      storage_gb: 5,
      campaigns_per_month: 4,
      posts_per_month: 40,
      videos_per_campaign: 2,
      images_per_campaign: 3,
      has_voice_autopilot: false,
      has_ai_assist: false,
      has_autonomous: false
    },
    'Entrepreneur' => {
      max_platforms: 6,
      storage_gb: 10,
      campaigns_per_month: 8,
      posts_per_month: 80,
      videos_per_campaign: 2,
      images_per_campaign: 3,
      has_voice_autopilot: true,
      has_ai_assist: true,
      has_autonomous: false
    },
    'Pro' => {
      max_platforms: 9,
      storage_gb: 20,
      campaigns_per_month: 12,
      posts_per_month: 120,
      videos_per_campaign: 2,
      images_per_campaign: 3,
      has_voice_autopilot: true,
      has_ai_assist: true,
      has_autonomous: true
    }
  }.freeze
  
  # Get current plan limits
  def plan_limits
    PLAN_LIMITS[subscription_plan] || PLAN_LIMITS['Starter']
  end
  
  def max_platforms
    plan_limits[:max_platforms]
  end
  
  def storage_limit_gb
    plan_limits[:storage_gb]
  end
  
  def max_campaigns_per_month
    plan_limits[:campaigns_per_month]
  end
  
  def max_posts_per_month
    plan_limits[:posts_per_month]
  end
  
  def videos_per_campaign
    plan_limits[:videos_per_campaign]
  end
  
  def images_per_campaign
    plan_limits[:images_per_campaign]
  end
  
  def has_voice_autopilot?
    plan_limits[:has_voice_autopilot]
  end
  
  def has_ai_assist?
    plan_limits[:has_ai_assist]
  end
  
  def has_autonomous?
    plan_limits[:has_autonomous]
  end
  
  # Role helpers
  def admin? = role == 'admin'
  def moderator? = role == 'moderator'
  def premium? = role == 'premium' || role == 'moderator' || role == 'admin'
  
  # Role-based authorization methods
  def can_access_feature?(feature_name)
    case feature_name
    when 'ai_advanced'
      paid_plan? || admin? || moderator?
    when 'voice_premium'
      paid_plan? || admin? || moderator?
    when 'analytics_advanced'
      pro? || admin?
    when 'automation_advanced'
      paid_plan? || admin? || moderator?
    when 'admin_features'
      admin? || moderator?
    when 'user_management'
      admin?
    else
      true # Default: allow access
    end
  end
  
  # Subscription and role combinations
  def can_create_campaigns?
    paid_plan? || admin? || moderator?
  end
  
  def can_schedule_posts?
    paid_plan? || admin? || moderator?
  end
  
  def can_use_ai_features?
    paid_plan? || admin? || moderator?
  end
  
  def can_access_analytics?
    paid_plan? || admin? || moderator?
  end
  
  def can_manage_automation?
    pro? || entrepreneur? || admin? || moderator?
  end

  # AI Auto-generation features (Pilot proactive content creation)
  # Starter = Manual input only
  # Entrepreneur = Voice command autopilot (assists when prompted, no autonomous workflows)
  # Pro = Full automation + workflows (can run autonomously)
  
  def can_use_ai_auto_generate?
    # Pro and Entrepreneur plans get AI auto-generation
    pro? || entrepreneur? || admin? || moderator?
  end

  def can_access_ai_content_ideas?
    # Content ideas = AI auto-generation feature
    can_use_ai_auto_generate?
  end

  def can_access_ai_image_ideas?
    # Image ideas = AI auto-generation feature
    can_use_ai_auto_generate?
  end

  def can_access_ai_video_ideas?
    # Video ideas = AI auto-generation feature
    can_use_ai_auto_generate?
  end

  def can_use_voice_autopilot?
    # Voice command autopilot available to Entrepreneur and Pro
    entrepreneur? || pro? || admin? || moderator?
  end

  def can_run_autonomous_workflows?
    # Full automation/workflows only on Pro plan
    pro? || admin? || moderator?
  end

  # Manual input features (user types what they want) - available to all plans
  def can_use_manual_content_generation?
    true # All users can manually input prompts
  end

  def can_use_manual_image_generation?
    true # All users can manually input prompts
  end

  def can_use_manual_video_generation?
    true # All users can manually input prompts
  end

  # Admin panel access
  def can_access_admin_panel?
    admin? || moderator?
  end
  
  # Role upgrade/downgrade validation
  def can_change_role_to?(new_role)
    return false unless ROLES.include?(new_role)
    
    # Prevent self-demotion from admin unless super admin exists
    return false if admin? && new_role != 'admin'
    
    # Only admins can change other users' roles
    admin?
  end

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end
  generates_token_for :password_reset, expires_in: 20.minutes

  has_many :sessions, dependent: :destroy
  has_many :otto_messages, dependent: :destroy if ActiveRecord::Base.connection.table_exists?(:otto_messages) rescue false
  has_many :payments, dependent: :destroy
  has_many :user_subscriptions, dependent: :destroy

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :password, allow_nil: true, length: { minimum: MIN_PASSWORD }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end

  # Associations for Ultimate Social Media platform
  has_many :campaigns, dependent: :destroy
  has_many :contents, dependent: :destroy
  has_many :social_accounts, dependent: :destroy
  has_many :scheduled_posts, dependent: :destroy
  has_many :voice_commands, dependent: :destroy
  
  # AI & Voice features
  has_many :ai_conversations, dependent: :destroy
  has_many :ai_messages, through: :ai_conversations
  has_many :voice_settings, dependent: :destroy
  has_many :content_suggestions, dependent: :destroy
  has_many :draft_contents, dependent: :destroy
  
  # Content & Scheduling features
  has_many :content_templates, dependent: :destroy
  has_many :automation_rules, dependent: :destroy
  has_many :scheduled_tasks, dependent: :destroy
  
  # Analytics features
  has_many :engagement_metrics, dependent: :destroy
  has_many :trend_analyses, dependent: :destroy
  has_many :buffer_analytics, through: :scheduled_posts
  
  # Automation features
  has_many :auto_response_triggers, dependent: :destroy
  has_many :scheduled_ai_tasks, dependent: :destroy
  has_many :trigger_executions, dependent: :destroy
  has_many :task_executions, dependent: :destroy
  has_many :workflows, dependent: :destroy
  has_many :workflow_steps, through: :workflows

  # OAuth methods
  def self.from_omniauth(auth)
    name = auth.info.name.presence || "#{SecureRandom.hex(10)}_user"
    email = auth.info.email.presence || User.generate_email(name)

    # First, try to find user by email
    user = find_by(email: email)
    if user
      user.update(provider: auth.provider, uid: auth.uid)
      return user
    end

    # Then, try to find user by provider and uid
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    # If not found, create a new user
    verified = !email.end_with?(GENERATED_EMAIL_SUFFIX)
    create(
      name: name,
      email: email,
      provider: auth.provider,
      uid: auth.uid,
      verified: verified,
    )
  end

  def self.generate_email(name)
    if name.present?
      name.downcase.gsub(' ', '_') + GENERATED_EMAIL_SUFFIX
    else
      SecureRandom.hex(10) + GENERATED_EMAIL_SUFFIX
    end
  end

  public

  def oauth_user?
    provider.present? && uid.present?
  end

  def email_was_generated?
    email.end_with?(GENERATED_EMAIL_SUFFIX)
  end

  def password_required?
    return false if oauth_user?
    password_digest.blank? || password.present?
  end

  # write your own code here

  # Onboarding tracking
  include OnboardingTrackable

  # Assistant conversations
  has_many :assistant_conversations, dependent: :destroy

end