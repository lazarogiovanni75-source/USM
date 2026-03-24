class ContentTemplate < ApplicationRecord
  # Associations
  has_many :content_template_variables, dependent: :destroy
  has_many :contents, through: :content_template_variables

  # Enums
  enum template_type: {
    social_post: "social_post",
    story: "story",
    video_script: "video_script",
    blog_post: "blog_post",
    email: "email",
    ad_copy: "ad_copy"
  }

  enum category: {
    marketing: "marketing",
    education: "education",
    entertainment: "entertainment",
    product: "product",
    announcement: "announcement",
    question: "question",
    quote: "quote",
    other: "other"
  }

  enum platform: {
    general: "general",
    facebook: "facebook",
    instagram: "instagram",
    twitter: "twitter",
    linkedin: "linkedin",
    tiktok: "tiktok",
    youtube: "youtube"
  }

  # Validations
  validates :name, presence: true, uniqueness: true
  validates :description, presence: true
  validates :template_content, presence: true
  validates :template_type, presence: true
  validates :category, presence: true
  validates :platform, presence: true

  # Scopes
  scope :featured, -> { where(is_featured: true) }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :by_platform, ->(platform) { where(platform: platform) }
  scope :by_category, ->(category) { where(category: category) }
  scope :for_platform, ->(platform) { where(platform: platform) }
  scope :user_templates, ->(user_id) { where(user_id: user_id) }
  scope :public_templates, -> { where(user_id: nil) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :search, ->(query) { where("name ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%") }

  # Methods

  # Extract variables from template content
  def extract_variables
    template_content.scan(/\{w+\}/).flatten.uniq
  end

  # Apply template with variables
  def apply_template(variables = {})
    content = template_content.dup
    variables.each do |key, value|
      content.gsub!("{#{key}}", value.to_s)
    end
    content
  end

  # Alias for apply_template (used by controller)
  def process_variables(variables = {})
    apply_template(variables)
  end

  # Check if template has specific variable
  def has_variable?(variable_name)
    template_content.include?("{#{variable_name}}")
  end

  # Get variable names with types
  def variable_definitions
    content_template_variables.map do |var|
      {
        name: var.variable_name,
        type: var.variable_type,
        default: var.default_value,
        placeholder: var.placeholder_text
      }
    end
  end

  # Increment the usage count
  def increment_usage
    update(usage_count: usage_count.to_i + 1)
  end
end
