class User < ApplicationRecord
  MIN_PASSWORD = 4
  GENERATED_EMAIL_SUFFIX = "@generated-mail.clacky.ai"

  has_secure_password validations: false

  # Role-based Access Control
  ROLES = %w[user premium moderator admin].freeze
  validates :role, inclusion: { in: ROLES }, if: -> { role.present? }
  
  # Subscription Plans
  SUBSCRIPTION_PLANS = %w[free basic premium enterprise].freeze
  validates :subscription_plan, inclusion: { in: SUBSCRIPTION_PLANS }, if: -> { subscription_plan.present? }
  
  # Helper methods
  def premium? = subscription_plan == 'premium' || subscription_plan == 'enterprise'
  def enterprise? = subscription_plan == 'enterprise'
  def admin? = role == 'admin'
  def moderator? = role == 'moderator'
  def free_plan? = subscription_plan == 'free' || subscription_plan.blank?
  
  # Role-based authorization methods
  def can_access_feature?(feature_name)
    case feature_name
    when 'ai_advanced'
      premium? || admin? || moderator?
    when 'voice_premium'
      premium? || admin? || moderator?
    when 'analytics_advanced'
      enterprise? || admin?
    when 'automation_advanced'
      premium? || admin? || moderator?
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
    !free_plan? || admin? || moderator?
  end
  
  def can_schedule_posts?
    !free_plan? || admin? || moderator?
  end
  
  def can_use_ai_features?
    !free_plan? || admin? || moderator?
  end
  
  def can_access_analytics?
    !free_plan? || admin? || moderator?
  end
  
  def can_manage_automation?
    premium? || enterprise? || admin? || moderator?
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
  has_many :performance_metrics, dependent: :destroy
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

end