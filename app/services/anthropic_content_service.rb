# Anthropic Claude Service for AI Content Generation
# Generates captions, blog posts, ad copy, and hashtags using Claude API
class AnthropicContentService
  class ContentGenerationError < StandardError; end

  PLATFORMS = %w[instagram linkedin x twitter tiktok facebook youtube pinterest threads].freeze
  BRAND_VOICES = %w[professional casual playful inspirational authoritative friendly witty bold].freeze
  CONTENT_TYPES = %w[caption blog_post ad_copy hashtag thread_story email_marketing].freeze
  OUTPUT_FORMATS = %w[short_form long_form carousel thread newsletter].freeze

  attr_reader :topic, :brand_voice, :platform, :content_type, :additional_context, :custom_system_prompt, :output_format

  def initialize(topic:, brand_voice: 'professional', platform: 'instagram', content_type: 'caption', additional_context: nil, custom_system_prompt: nil, output_format: 'short_form')
    @topic = topic
    @brand_voice = brand_voice
    @platform = platform
    @content_type = content_type
    @additional_context = additional_context
    @custom_system_prompt = custom_system_prompt
    @output_format = output_format
  end

  def generate
    Rails.logger.info "[AnthropicContent] Generating #{content_type} for #{platform} with #{brand_voice} voice (format: #{output_format})"

    case content_type.to_s.downcase
    when 'caption'
      generate_caption
    when 'blog_post'
      generate_blog_post
    when 'ad_copy'
      generate_ad_copy
    when 'hashtag'
      generate_hashtags
    when 'thread_story'
      generate_thread_story
    when 'email_marketing'
      generate_email_marketing
    else
      generate_caption
    end
  rescue => e
    Rails.logger.error "[AnthropicContent] Error generating content: #{e.message}"
    raise ContentGenerationError, "Failed to generate content: #{e.message}"
  end

  def generate_all
    Rails.logger.info "[AnthropicContent] Generating all content types for #{platform}"

    results = {}
    errors = {}

    CONTENT_TYPES.each do |type|
      begin
        results[type] = send("generate_#{type.gsub('_', '_')}")
      rescue => e
        errors[type] = e.message
        Rails.logger.warn "[AnthropicContent] Failed to generate #{type}: #{e.message}"
      end
    end

    {
      caption: results['caption'] || results[:caption],
      blog_post: results['blog_post'] || results[:blog_post],
      ad_copy: results['ad_copy'] || results[:ad_copy],
      hashtags: results['hashtag'] || results[:hashtag],
      thread_story: results['thread_story'] || results[:thread_story],
      email_marketing: results['email_marketing'] || results[:email_marketing],
      errors: errors,
      platform: platform,
      brand_voice: brand_voice,
      topic: topic,
      output_format: output_format
    }
  end

  def self.generate_all_content(topic:, brand_voice: 'professional', platform: 'instagram', additional_context: nil, custom_system_prompt: nil, output_format: 'short_form')
    service = new(
      topic: topic,
      brand_voice: brand_voice,
      platform: platform,
      content_type: 'all',
      additional_context: additional_context,
      custom_system_prompt: custom_system_prompt,
      output_format: output_format
    )
    service.generate_all
  end

  def self.platforms
    PLATFORMS
  end

  def self.brand_voices
    BRAND_VOICES
  end

  def self.content_types
    CONTENT_TYPES
  end

  def self.output_formats
    OUTPUT_FORMATS
  end

  private

  def generate_caption
    prompt = build_caption_prompt
    call_claude(prompt)
  end

  def generate_blog_post
    prompt = build_blog_post_prompt
    call_claude(prompt)
  end

  def generate_ad_copy
    prompt = build_ad_copy_prompt
    call_claude(prompt)
  end

  def generate_hashtags
    prompt = build_hashtag_prompt
    call_claude(prompt)
  end

  def generate_thread_story
    prompt = build_thread_story_prompt
    call_claude(prompt)
  end

  def generate_email_marketing
    prompt = build_email_marketing_prompt
    call_claude(prompt)
  end

  def build_system_prompt
    # Custom system prompt takes precedence, otherwise use brand voice
    return custom_system_prompt if custom_system_prompt.present?

    # Build system prompt from brand voice
    voice_descriptions = {
      'professional' => 'You are a professional content creator with expertise in business communication. Your writing is polished, authoritative, and trustworthy.',
      'casual' => 'You are a friendly content creator who writes in a relaxed, conversational tone. Your content feels like chatting with a good friend.',
      'playful' => 'You are a creative content creator with a fun, energetic personality. Your writing is witty, entertaining, and brings joy to readers.',
      'inspirational' => 'You are an motivational content creator focused on empowering and uplifting your audience. Your words inspire action and positive change.',
      'authoritative' => 'You are an expert content creator with deep industry knowledge. Your writing establishes thought leadership and credibility.',
      'friendly' => 'You are a warm, approachable content creator who makes everyone feel welcome. Your tone is personal and engaging.',
      'witty' => 'You are a clever content creator with sharp humor and intelligence. Your writing entertains while delivering value.',
      'bold' => 'You are a fearless content creator who makes strong statements and challenges conventions. Your voice is confident and unapologetic.'
    }

    base_prompt = voice_descriptions[brand_voice] || voice_descriptions['professional']
    "#{base_prompt} You create content optimized for #{platform} platform."
  end

  def format_guidelines
    case output_format.to_s.downcase
    when 'short_form'
      'Keep content concise and impactful. Ideal for quick consumption.'
    when 'long_form'
      'Provide comprehensive, detailed content. Include all relevant information and depth.'
    when 'carousel'
      'Structure content as slides/posts that work as a visual carousel. Each section should be self-contained.'
    when 'thread'
      'Format as a thread with multiple connected posts. Hook in first, deliver value progressively.'
    when 'newsletter'
      'Structure as an email newsletter with subject line, preview text, greeting, body sections, and CTA.'
    else
      'Follow platform best practices.'
    end
  end

  def build_caption_prompt
    platform_guidelines = get_platform_guidelines

    <<~PROMPT
      #{build_system_prompt}

      Generate a #{platform} caption.

      Topic: #{topic}
      Output Format: #{output_format}
      Platform: #{platform}

      #{platform_guidelines}

      #{additional_context.present? ? "Additional Context: #{additional_context}" : ""}

      Requirements:
      - Use the #{brand_voice} brand voice consistently
      - Make it engaging and relatable
      - Include a clear call-to-action where appropriate
      - Keep within #{platform} character limits (if applicable)
      - Make it authentic and avoid clickbait
      - #{format_guidelines}

      Return the caption only, no explanations or headers.
    PROMPT
  end

  def build_blog_post_prompt
    <<~PROMPT
      #{build_system_prompt}

      Generate a blog post.

      Topic: #{topic}
      Output Format: #{output_format}
      Brand Voice: #{brand_voice}

      #{additional_context.present? ? "Additional Context: #{additional_context}" : ""}

      Requirements:
      - Use #{brand_voice} tone throughout
      - Structure with compelling headline, intro, body sections, and conclusion
      - Include SEO-friendly subheadings
      - Target approximately #{word_count_for_format} words
      - Make it scannable with short paragraphs
      - Include relevant statistics or examples where applicable
      - End with a clear call-to-action
      - #{format_guidelines}

      Return the complete blog post with title and sections clearly marked.
    PROMPT
  end

  def build_ad_copy_prompt
    <<~PROMPT
      #{build_system_prompt}

      Generate ad copy for #{platform}.

      Product/Service: #{topic}
      Brand Voice: #{brand_voice}
      Output Format: #{output_format}
      Platform: #{platform}

      #{additional_context.present? ? "Additional Context: #{additional_context}" : ""}

      Requirements:
      - Use #{brand_voice} tone that resonates with target audience
      - Create urgency without being pushy
      - Highlight key benefits and unique selling points
      - Include compelling headline (max 125 characters for search ads, or platform-appropriate)
      - Write 2-3 ad variations with different angles
      - Include clear CTA in each variation
      - #{format_guidelines}

      Format as:
      HEADLINE: [headline]
      BODY: [ad copy]
      CTA: [call to action]

      (Repeat for each variation)
    PROMPT
  end

  def build_hashtag_prompt
    <<~PROMPT
      #{build_system_prompt}

      Generate relevant, trending-style hashtags for #{platform}.

      Topic: #{topic}
      Platform: #{platform}
      Output Format: #{output_format}

      Requirements:
      - Generate 20-30 hashtags
      - Mix of popular and niche hashtags
      - Include platform-specific hashtag strategies for #{platform}
      - Group them logically: industry, topic, brand, trending
      - Avoid banned or overused hashtags
      - #{format_guidelines}

      Format hashtags separated by spaces, grouped by category with comments:
      #industry #topic #trending
      #brand #community
      #niche1 #niche2
    PROMPT
  end

  def build_thread_story_prompt
    <<~PROMPT
      #{build_system_prompt}

      Generate a Twitter/X thread or LinkedIn carousel story.

      Topic: #{topic}
      Brand Voice: #{brand_voice}
      Platform: #{platform}
      Output Format: #{output_format}

      #{additional_context.present? ? "Additional Context: #{additional_context}" : ""}

      Requirements:
      - Create 5-10 engaging thread posts
      - Hook readers in the first post
      - Build narrative or provide value progressively
      - End with engagement prompt
      - Each post should be under 280 characters (for X/Twitter)
      - For LinkedIn, posts can be longer
      - #{format_guidelines}

      Format as numbered thread:
      [1/10] First hook post
      [2/10] Continue story...
      ... and so on
    PROMPT
  end

  def build_email_marketing_prompt
    <<~PROMPT
      #{build_system_prompt}

      Generate an email marketing campaign.

      Topic/Offer: #{topic}
      Brand Voice: #{brand_voice}
      Output Format: #{output_format}

      #{additional_context.present? ? "Additional Context: #{additional_context}" : ""}

      Requirements:
      - Write compelling subject line with 3-5 alternatives
      - Create preview text (under 100 characters)
      - Write personal greeting
      - Structure with engaging opening, body content, and strong CTA
      - Include email signature placeholders
      - Make it conversational and value-driven
      - Optimize for both desktop and mobile
      - #{format_guidelines}

      Format:
      SUBJECT: [subject line]
      PREVIEW: [preview text]
      ---
      [Full email content]
    PROMPT
  end

  def word_count_for_format
    case output_format.to_s.downcase
    when 'short_form' then '400-600'
    when 'long_form' then '1200-1500'
    when 'carousel' then '600-800'
    when 'thread' then '500-700'
    when 'newsletter' then '400-600'
    else '800-1000'
    end
  end

  def get_platform_guidelines
    guidelines = {
      'instagram' => 'Instagram: Use line breaks for readability. Emojis add engagement. Keep captions 150-300 characters for best reach, but can go up to 2200.',
      'linkedin' => 'LinkedIn: Professional tone. Use paragraphs. Include 1-2 relevant hashtags. 1300-3000 characters optimal.',
      'x' => 'X/Twitter: Max 280 characters per tweet. Be punchy. Thread format for longer content.',
      'twitter' => 'X/Twitter: Max 280 characters per tweet. Be punchy. Thread format for longer content.',
      'tiktok' => 'TikTok: Casual, trendy tone. Include hook in first line. Encourage engagement with questions or CTAs.',
      'facebook' => 'Facebook: Conversational, shareable. Use storytelling. 40-80 characters for links get most clicks.',
      'youtube' => 'YouTube: Engaging hooks. Explain value proposition. Include timestamps. End with engagement prompts.',
      'pinterest' => 'Pinterest: Inspirational, visual-friendly. Action-oriented. Include keywords naturally.',
      'threads' => 'Threads: Conversational, casual. Hook in first line. Encourage replies. Can be longer than X.'
    }
    guidelines[platform] || 'Follow platform best practices for engagement.'
  end

  def call_claude(prompt)
    api_key = ENV.fetch('ANTHROPIC_API_KEY', ENV.fetch('CLACKY_ANTHROPIC_API_KEY', nil))

    raise ContentGenerationError, 'Anthropic API key not configured' unless api_key

    uri = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri, {
      'Content-Type' => 'application/json',
      'x-api-key' => api_key,
      'anthropic-version' => '2023-06-01',
      'anthropic-dangerous-direct-browser-access' => 'true'
    })

    request.body = {
      model: 'claude-sonnet-4-20250514',
      max_tokens: 4096,
      messages: [{ role: 'user', content: prompt }]
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "[AnthropicContent] API Error: #{response.code} - #{response.body}"
      raise ContentGenerationError, "API request failed: #{response.code}"
    end

    parsed = JSON.parse(response.body)
    content = parsed.dig('content', 0, 'text')

    raise ContentGenerationError, 'No content returned from API' unless content.present?

    content
  rescue JSON::ParserError => e
    Rails.logger.error "[AnthropicContent] JSON Parse Error: #{e.message}"
    raise ContentGenerationError, 'Failed to parse API response'
  rescue => e
    Rails.logger.error "[AnthropicContent] Unexpected Error: #{e.message}"
    raise ContentGenerationError, e.message
  end
end
