# Anthropic Content Service - Generates AI content using Claude
class AnthropicContentService
  class ContentGenerationError < StandardError; end

  def initialize(topic:, brand_voice: 'professional', platform: 'general', content_type: 'caption', additional_context: nil)
    @topic = topic
    @brand_voice = brand_voice
    @platform = platform
    @content_type = content_type
    @additional_context = additional_context
  end

  def self.generate_all_content(topic:, brand_voice: 'professional', platform: 'general', additional_context: nil, user: nil)
    new(
      topic: topic,
      brand_voice: brand_voice,
      platform: platform,
      additional_context: additional_context
    ).generate_all(user: user)
  end

  def self.platforms
    ['Twitter', 'Facebook', 'Instagram', 'LinkedIn', 'TikTok', 'general']
  end

  def self.brand_voices
    ['professional', 'casual', 'humorous', 'inspirational', 'educational']
  end

  def self.content_types
    ['caption', 'blog_post', 'ad_copy', 'hashtags', 'thread_story', 'email_marketing', 'all']
  end

  def self.output_formats
    ['text', 'formatted', 'json']
  end

  def generate(user: nil)
    prompt = build_prompt
    LlmService.generate(prompt, user: user)
  end

  def generate_all(user: nil)
    {
      caption: generate_captions(user: user),
      blog_post: generate_blog_post(user: user),
      ad_copy: generate_ad_copy(user: user),
      hashtags: generate_hashtags(user: user),
      thread_story: generate_thread(user: user),
      email_marketing: generate_email(user: user)
    }
  end

  private

  def build_prompt
    base = "Generate #{@content_type} for #{@platform} about: #{@topic}"
    base += ". Brand voice: #{@brand_voice}"
    base += ". Additional context: #{@additional_context}" if @additional_context
    base
  end

  def generate_captions(user: nil)
    LlmService.generate("Create engaging #{@platform} captions about #{@topic}. Brand voice: #{@brand_voice}", user: user)
  end

  def generate_blog_post(user: nil)
    LlmService.generate("Write a blog post about #{@topic}. Include introduction, main points, and conclusion.", user: user)
  end

  def generate_ad_copy(user: nil)
    LlmService.generate("Create compelling ad copy for #{@topic}. Target audience: #{@brand_voice}", user: user)
  end

  def generate_hashtags(user: nil)
    LlmService.generate("Suggest relevant hashtags for #{@topic} on #{@platform}", user: user)
  end

  def generate_thread(user: nil)
    LlmService.generate("Create a thread about #{@topic} for #{@platform}", user: user)
  end

  def generate_email(user: nil)
    LlmService.generate("Write email marketing content about #{@topic}", user: user)
  end
end
