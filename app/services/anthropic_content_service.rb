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

  def self.generate_all_content(topic:, brand_voice: 'professional', platform: 'general', additional_context: nil)
    new(
      topic: topic,
      brand_voice: brand_voice,
      platform: platform,
      additional_context: additional_context
    ).generate_all
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

  def generate
    prompt = build_prompt
    LlmService.generate(prompt)
  end

  def generate_all
    {
      caption: generate_captions,
      blog_post: generate_blog_post,
      ad_copy: generate_ad_copy,
      hashtags: generate_hashtags,
      thread_story: generate_thread,
      email_marketing: generate_email
    }
  end

  private

  def build_prompt
    base = "Generate #{@content_type} for #{@platform} about: #{@topic}"
    base += ". Brand voice: #{@brand_voice}"
    base += ". Additional context: #{@additional_context}" if @additional_context
    base
  end

  def generate_captions
    LlmService.generate("Create engaging #{@platform} captions about #{@topic}. Brand voice: #{@brand_voice}")
  end

  def generate_blog_post
    LlmService.generate("Write a blog post about #{@topic}. Include introduction, main points, and conclusion.")
  end

  def generate_ad_copy
    LlmService.generate("Create compelling ad copy for #{@topic}. Target audience: #{@brand_voice}")
  end

  def generate_hashtags
    LlmService.generate("Suggest relevant hashtags for #{@topic} on #{@platform}")
  end

  def generate_thread
    LlmService.generate("Create a thread about #{@topic} for #{@platform}")
  end

  def generate_email
    LlmService.generate("Write email marketing content about #{@topic}")
  end
end
