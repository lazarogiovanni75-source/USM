class AiGeneratedContent < ApplicationRecord
  belongs_to :user

  validates :topic, presence: true
  validates :platform, presence: true, inclusion: { in: %w[instagram linkedin x twitter tiktok facebook youtube pinterest threads] }
  validates :brand_voice, presence: true, inclusion: { in: %w[professional casual playful inspirational authoritative friendly witty bold] }
  validates :content_type, presence: true, inclusion: { in: %w[caption blog_post ad_copy hashtag thread_story email_marketing all] }
  validates :output_format, presence: true, inclusion: { in: %w[short_form long_form carousel thread newsletter] }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_platform, ->(platform) { where(platform: platform) if platform.present? }
  scope :by_content_type, ->(type) { where(content_type: type) if type.present? }
  scope :by_format, ->(format) { where(output_format: format) if format.present? }
  scope :edited, -> { where(is_edited: true) }

  def display_caption
    caption.presence || 'Caption not generated'
  end

  def display_blog_post
    blog_post.presence || 'Blog post not generated'
  end

  def display_ad_copy
    ad_copy.presence || 'Ad copy not generated'
  end

  def display_hashtags
    hashtags.presence || 'Hashtags not generated'
  end

  def display_thread_story
    thread_story.presence || 'Thread/story not generated'
  end

  def display_email_marketing
    email_marketing.presence || 'Email marketing not generated'
  end

  def output_format_display
    format_labels = {
      'short_form' => 'Short Form',
      'long_form' => 'Long Form',
      'carousel' => 'Carousel',
      'thread' => 'Thread',
      'newsletter' => 'Newsletter'
    }
    format_labels[output_format] || output_format
  end

  def brand_voice_display
    voice_labels = {
      'professional' => 'Professional',
      'casual' => 'Casual',
      'playful' => 'Playful',
      'inspirational' => 'Inspirational',
      'authoritative' => 'Authoritative',
      'friendly' => 'Friendly',
      'witty' => 'Witty',
      'bold' => 'Bold'
    }
    voice_labels[brand_voice] || brand_voice
  end

  def platform_display
    platform_labels = {
      'instagram' => 'Instagram',
      'linkedin' => 'LinkedIn',
      'x' => 'X (Twitter)',
      'twitter' => 'X (Twitter)',
      'tiktok' => 'TikTok',
      'facebook' => 'Facebook',
      'youtube' => 'YouTube',
      'pinterest' => 'Pinterest',
      'threads' => 'Threads'
    }
    platform_labels[platform] || platform
  end

  def mark_as_edited!
    update!(is_edited: true)
  end
end
