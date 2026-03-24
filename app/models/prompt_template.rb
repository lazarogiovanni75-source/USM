class PromptTemplate < ApplicationRecord
  # Associations
  belongs_to :user, optional: true
  
  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :category, presence: true, length: { maximum: 50 }
  validates :prompt, presence: true, length: { maximum: 2000 }
  validates :description, length: { maximum: 500 }, allow_blank: true
  
  # Enums and constants
  CATEGORIES = [
    'content_creation',
    'social_media',
    'marketing',
    'blog_writing',
    'email_marketing',
    'product_descriptions',
    'ad_copy',
    'customer_service',
    'sales_copy',
    'education',
    'entertainment',
    'productivity',
    'creative_writing',
    'technical',
    'other'
  ].freeze
  
  # Scopes
  scope :by_category, ->(category) { where(category: category) }
  scope :user_templates, -> { where.not(user_id: nil) }
  scope :system_templates, -> { where(user_id: nil) }
  scope :public_templates, -> { where(is_public: true) }
  scope :featured_templates, -> { where(is_featured: true) }
  scope :active_templates, -> { where(is_active: true) }
  scope :by_usage, -> { order(usage_count: :desc) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Callbacks
  before_save :set_default_values
  before_save :validate_template_variables
  after_save :update_usage_statistics
  
  # Attributes
  attribute :is_public, :boolean, default: false
  attribute :is_featured, :boolean, default: false
  attribute :is_active, :boolean, default: true
  attribute :usage_count, :integer, default: 0
  attribute :rating_average, :decimal, precision: 3, scale: 2, default: 0.0
  attribute :rating_count, :integer, default: 0
  
  # Serialized data
  serialize :variables, Hash
  serialize :metadata, Hash
  serialize :tags, Array
  
  # Template variable pattern matching
  VARIABLE_PATTERN = /\{\{(\w+)\}\}/.freeze
  
  def initialize(attributes = nil)
    super
    self.variables ||= {}
    self.metadata ||= {}
    self.tags ||= []
  end
  
  # Template processing methods
  def process_template(variables = {})
    processed_prompt = prompt.dup
    
    # Replace variables in the format {{variable_name}}
    variables.each do |key, value|
      processed_prompt.gsub!("{{#{key}}}", value.to_s)
    end
    
    # Replace any remaining variables with empty strings
    processed_prompt.gsub!(VARIABLE_PATTERN, '')
    
    processed_prompt
  end
  
  def extract_variables
    prompt.scan(VARIABLE_PATTERN).flatten.uniq
  end
  
  def missing_variables(provided_variables = {})
    required_vars = extract_variables
    required_vars - provided_variables.keys.map(&:to_s)
  end
  
  def valid_with_variables?(variables = {})
    missing_variables(variables).empty?
  end
  
  # Rating system
  def rate_template(rating)
    rating = rating.to_i
    rating = 1 if rating < 1
    rating = 5 if rating > 5
    
    # Update average rating
    total_rating = rating_average * rating_count + rating
    new_count = rating_count + 1
    
    update!(
      rating_average: total_rating / new_count,
      rating_count: new_count
    )
  end
  
  # Usage tracking
  def increment_usage
    increment(:usage_count)
  end
  
  def usage_rate
    return 0 if created_at.nil?
    
    days_since_created = (Time.current - created_at).to_i / (24 * 60 * 60)
    days_since_created = 1 if days_since_created < 1
    
    usage_count.to_f / days_since_created
  end
  
  # Template duplication
  def duplicate_for_user(new_user)
    template_attrs = attributes.except('id', 'user_id', 'created_at', 'updated_at', 'usage_count', 'rating_average', 'rating_count')
    template_attrs['user_id'] = new_user.id
    template_attrs['name'] = "#{name} (Copy)"
    template_attrs['is_public'] = false
    
    self.class.create!(template_attrs)
  end
  
  # Search functionality
  def self.search(query)
    where(
      'name ILIKE :query OR description ILIKE :query OR prompt ILIKE :query',
      query: "%#{query}%"
    )
  end
  
  def self.search_with_tags(tags)
    return all if tags.empty?
    
    conditions = tags.map { "tags @> '['%#{sanitize_sql_like}%']'" }.join(' OR ')
    where(conditions)
  end
  
  # Category statistics
  def self.category_stats
    CATEGORIES.map do |category|
      count = where(category: category).count
      {
        category: category.humanize,
        count: count,
        percentage: (count.to_f / count.to_f * 100).round(1)
      }
    end
  end
  
  # Popular templates
  def self.popular_templates(limit = 10)
    active_templates.public_or_user_templates(User.current).order(usage_count: :desc).limit(limit)
  end
  
  # Featured templates for homepage
  def self.featured_for_display
    active_templates.featured.public_or_user_templates(User.current).order(usage_count: :desc).limit(6)
  end
  
  # Template categories with counts
  def self.categories_with_counts
    CATEGORIES.map do |category|
      count = active_templates.by_category(category).count
      {
        name: category.humanize,
        slug: category,
        count: count,
        templates: active_templates.by_category(category).limit(4).to_a
      }
    end.select { |cat| cat[:count] > 0 }
  end
  
  # Access control helpers
  def can_be_viewed_by?(user)
    is_public || (user.present? && user_id == user.id)
  end
  
  def can_be_edited_by?(user)
    user.present? && (user_id == user.id || user.admin?)
  end
  
  def can_be_deleted_by?(user)
    can_be_edited_by?(user)
  end
  
  # Scoping for user access
  def self.accessible_to(user)
    if user.present?
      where('is_public = true OR user_id = ?', user.id)
    else
      public_templates
    end
  end
  
  # Additional scope for user vs system templates
  def self.public_or_user_templates(user)
    if user.present?
      where('is_public = true OR user_id = ?', user.id)
    else
      public_templates
    end
  end
  
  # Template validation
  def validate_template_variables
    required_vars = extract_variables
    
    # Store variable information
    self.variables = required_vars.each_with_object({}) do |var, hash|
      hash[var] = {
        description: "Variable for #{var}",
        required: true,
        type: 'string'
      }
    end
  end
  
  # Usage analytics
  def usage_analytics
    {
      total_usage: usage_count,
      average_rating: rating_average,
      total_ratings: rating_count,
      usage_rate: usage_rate,
      created_date: created_at,
      last_used: metadata['last_used_at']
    }
  end
  
  # Template export/import
  def export_to_hash
    {
      name: name,
      description: description,
      category: category,
      prompt: prompt,
      variables: variables,
      tags: tags,
      is_public: is_public,
      metadata: metadata.except('created_by', 'last_used_at')
    }
  end
  
  def self.import_from_hash(hash, user)
    template_attrs = hash.except('id', 'user_id', 'usage_count', 'rating_average', 'rating_count')
    template_attrs['user_id'] = user.id
    
    create!(template_attrs)
  end
  
  private
  
  def set_default_values
    self.is_active = true if is_active.nil?
    self.is_public = false if is_public.nil?
    self.is_featured = false if is_featured.nil?
  end
  
  def update_usage_statistics
    # This could be moved to a background job for better performance
    self.metadata ||= {}
    self.metadata['last_updated'] = Time.current
    
    if will_save? && usage_count_changed?
      self.metadata['last_used_at'] = Time.current
    end
  end
end