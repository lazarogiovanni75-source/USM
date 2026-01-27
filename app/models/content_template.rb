class ContentTemplate < ApplicationRecord
  # Associations
  has_many :content_template_variables, dependent: :destroy
  has_many :contents, through: :content_template_variables

  # Enums
  enum :template_type, {
    social_post: "social_post",
    story: "story",
    video_script: "video_script",
    blog_post: "blog_post",
    email: "email",
    ad_copy: "ad_copy"
  }

  enum :category, {
    marketing: "marketing",
    education: "education",
    entertainment: "entertainment",
    product: "product",
    announcement: "announcement",
    question: "question",
    quote: "quote",
    other: "other"
  }

  enum :platform, {
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

  # Methods

  # Extract variables from template content
  def extract_variables
    template_content.scan(/\{\w+\}/).flatten.uniq
  end

  # Apply template with variables
  def apply_template(variables = {})
    content = template_content.dup
    variables.each do |key, value|
      content.gsub!("{#{key}}", value.to_s)
    end
    content
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

  # Create starter pack templates
  def self.create_starter_pack_templates
    templates = [
      {
        name: "Product Launch Announcement",
        description: "Announce a new product with excitement and key benefits",
        template_content: "🚀 Exciting news! We're launching {product_name} - {key_benefit} that will change how you {use_case}. \n\n✨ What makes it special:\n{benefit_1}\n{benefit_2}\n{benefit_3}\n\n🎯 Perfect for {target_audience}\n\nReady to experience the future? {cta}\n\n#productlaunch #innovation #{hashtag_1} #{hashtag_2}",
        template_type: :social_post,
        category: :product,
        platform: :general,
        is_featured: true
      },
      {
        name: "Educational Tip Post",
        description: "Share valuable tips in an engaging, educational format",
        template_content: "💡 Pro Tip: {tip_title}\n\nDid you know that {fact_or_statistic}? Here's how you can {action_step_1}:\n\n1. {step_1}\n2. {step_2}\n3. {step_3}\n\n💬 What's your experience with this? Share in the comments!\n\n#{hashtag_1} #{hashtag_2} #education #tips",
        template_type: :social_post,
        category: :education,
        platform: :general,
        is_featured: true
      },
      {
        name: "Behind the Scenes Story",
        description: "Show your audience the process and people behind your work",
        template_content: "👀 Behind the Scenes: {project_or_process_name}\n\nEver wondered {question_about_process}? Here's what really goes on:\n\n🎬 Day in the life of {team_member_or_role}:\n{activity_1}\n{activity_2}\n{activity_3}\n\nThe best part? {favorite_aspect}\n\nWhat would you like to see next? 🤔\n\n#behindthescenes #{hashtag_1} #teamwork",
        template_type: :story,
        category: :marketing,
        platform: :general,
        is_featured: true
      },
      {
        name: "Customer Testimonial",
        description: "Feature customer success stories and testimonials",
        template_content: "🌟 Customer Spotlight: {customer_name}\n\n\"{testimonial_quote}\" - {customer_name}\n\n{customer_name} has been using {product_service} for {time_period} and the results are incredible:\n\n✅ {result_1}\n✅ {result_2}\n✅ {result_3}\n\nReady to achieve similar results? {cta}\n\n#customerstory #success #testimonial",
        template_type: :social_post,
        category: :marketing,
        platform: :general,
        is_featured: false
      },
      {
        name: "Question & Engagement",
        description: "Ask engaging questions to boost comments and interaction",
        template_content: "🤔 Quick question for you:\n\n{question_text}\n\nI'd love to hear your thoughts on this! 🤔\n\nA) {option_a}\nB) {option_b}\nC) {option_c}\n\nDrop your answer in the comments and let me know why! 👇\n\n#community #{hashtag_1} #discussion",
        template_type: :social_post,
        category: :question,
        platform: :general,
        is_featured: true
      },
      {
        name: "Instagram Story Template",
        description: "Perfect template for Instagram stories with polls and questions",
        template_content: "📱 Story: {story_topic}\n\nPoll: {poll_question}\n✅ {poll_option_1}\n❌ {poll_option_2}\n\nQuestion sticker: {question_for_audience}\n\n{fun_fact_or_statistic}\n\nLink in bio: {relevant_link}",
        template_type: :story,
        category: :entertainment,
        platform: :instagram,
        is_featured: true
      },
      {
        name: "LinkedIn Professional Post",
        description: "Professional content suitable for LinkedIn audience",
        template_content: "🔍 Industry Insight: {topic_or_trend}\n\nAfter {time_period} of analyzing {relevant_data_or_experience}, here are my key takeaways:\n\n📊 Key Finding 1: {finding_1}\n📊 Key Finding 2: {finding_2}\n📊 Key Finding 3: {finding_3}\n\n💡 My recommendation: {recommendation}\n\nWhat trends are you seeing in your industry? Let's discuss in the comments.\n\n#{industry_hashtag} #insights #professionaldevelopment",
        template_type: :social_post,
        category: :education,
        platform: :linkedin,
        is_featured: true
      },
      {
        name: "Twitter Thread Starter",
        description: "Great for Twitter threads with numbered points",
        template_content: "🧵 THREAD: {thread_topic} ({number_of_tweets} tweets)\n\n1/{number_of_tweets} {intro_point}\n\n2/{number_of_tweets} {point_1}\n\n3/{number_of_tweets} {point_2}\n\n4/{number_of_tweets} {point_3}\n\n{number_of_tweets}/{number_of_tweets} {conclusion_point}\n\nRT if this was helpful! 🔄\n\n#{hashtag_1} #{hashtag_2} #thread",
        template_type: :social_post,
        category: :education,
        platform: :twitter,
        is_featured: true
      },
      {
        name: "Motivational Quote Share",
        description: "Share inspirational quotes with your personal touch",
        template_content: "\"{quote_text}\" - {quote_author}\n\n{personal_reflection_or_story}\n\nThis resonates with me because {why_it_matters_to_you}.\n\nWhat's a quote that inspires you? Share it below! 👇\n\n#inspiration #{hashtag_1} #motivation",
        template_type: :social_post,
        category: :quote,
        platform: :general,
        is_featured: false
      },
      {
        name: "Event Announcement",
        description: "Announce events with all necessary details",
        template_content: "📅 EVENT ANNOUNCEMENT: {event_name}\n\n🗓️ Date: {event_date}\n⏰ Time: {event_time}\n📍 Location: {event_location}\n💰 Price: {ticket_price_or_free}\n\n🎯 What to expect:\n{highlight_1}\n{highlight_2}\n{highlight_3}\n\n🎫 Get your tickets: {ticket_link}\n\nWho's excited? Drop a 🙋‍♂️ below!\n\n#{event_hashtag} #{hashtag_1} #networking",
        template_type: :social_post,
        category: :announcement,
        platform: :general,
        is_featured: true
      }
    ]
    
    templates.each do |template_data|
      template = create!(template_data)
      
      # Add default variables based on template content
      variables = template.extract_variables
      variables.each do |var_name|
        template.content_template_variables.create!(
          variable_name: var_name,
          variable_type: 'text',
          default_value: '',
          placeholder_text: var_name.humanize,
          validation_rules: {}
        )
      end
    end
  end
end