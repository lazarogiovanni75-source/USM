class DraftService
  def self.generate_suggestions(draft)
    return if draft.content.blank?

    suggestions = []
    
    # Analyze content length
    if draft.content.length < 50
      suggestions << {
        topic: 'Content Length',
        suggestion: 'Consider expanding your content. Posts under 50 characters might not provide enough value.',
        confidence: 0.9,
        content_type: draft.content_type
      }
    elsif draft.content.length > 280 && draft.platform == 'twitter'
      suggestions << {
        topic: 'Character Limit',
        suggestion: 'Your content exceeds Twitter\'s 280 character limit. Consider shortening or using threads.',
        confidence: 0.95,
        content_type: draft.content_type
      }
    end

    # Platform-specific suggestions
    case draft.platform.downcase
    when 'instagram'
      suggestions << analyze_instagram_content(draft.content)
    when 'linkedin'
      suggestions << analyze_linkedin_content(draft.content)
    when 'twitter'
      suggestions << analyze_twitter_content(draft.content)
    when 'facebook'
      suggestions << analyze_facebook_content(draft.content)
    when 'tiktok'
      suggestions << analyze_tiktok_content(draft.content)
    end

    # Generate suggestions
    suggestions.compact.each do |suggestion|
      draft.content_suggestions.create!(
        topic: suggestion[:topic],
        suggestion: suggestion[:suggestion],
        confidence: suggestion[:confidence],
        content_type: draft.content_type,
        status: 'pending'
      )
    end
  end

  def self.analyze_instagram_content(content)
    # Check for hashtags
    hashtag_count = content.scan(/#\w+/).length
    if hashtag_count == 0
      return {
        topic: 'Hashtags',
        suggestion: 'Instagram performs better with hashtags. Consider adding 5-10 relevant hashtags.',
        confidence: 0.8,
        content_type: 'post'
      }
    elsif hashtag_count > 10
      return {
        topic: 'Hashtag Optimization',
        suggestion: 'You might be using too many hashtags. Stick to 5-10 for best engagement.',
        confidence: 0.7,
        content_type: 'post'
      }
    end

    # Check for mentions
    mention_count = content.scan(/@\w+/).length
    if mention_count == 0
      return {
        topic: 'Engagement',
        suggestion: 'Consider mentioning relevant accounts to increase visibility and engagement.',
        confidence: 0.6,
        content_type: 'post'
      }
    end

    # Check for call-to-action
    cta_words = ['click', 'link', 'visit', 'shop', 'buy', 'learn', 'follow', 'like', 'comment', 'share']
    if !cta_words.any? { |word| content.downcase.include?(word) }
      return {
        topic: 'Call to Action',
        suggestion: 'Add a clear call-to-action to encourage user engagement.',
        confidence: 0.75,
        content_type: 'post'
      }
    end

    nil
  end

  def self.analyze_linkedin_content(content)
    # Check for professional tone
    professional_words = ['professional', 'industry', 'career', 'business', 'strategy', 'insights', 'experience']
    if !professional_words.any? { |word| content.downcase.include?(word) }
      return {
        topic: 'Professional Tone',
        suggestion: 'LinkedIn audiences expect professional content. Consider adding industry insights or professional value.',
        confidence: 0.8,
        content_type: 'post'
      }
    end

    # Check for storytelling elements
    story_indicators = ['story', 'experience', 'learned', 'discovered', 'journey', 'challenge', 'success']
    if !story_indicators.any? { |word| content.downcase.include?(word) }
      return {
        topic: 'Storytelling',
        suggestion: 'Personal stories perform well on LinkedIn. Consider sharing a relevant experience or lesson learned.',
        confidence: 0.7,
        content_type: 'post'
      }
    end

    # Check for length (LinkedIn posts work best between 150-300 words)
    word_count = content.split.length
    if word_count < 100
      return {
        topic: 'Content Depth',
        suggestion: 'LinkedIn favors longer, more thoughtful posts. Consider expanding your content to provide more value.',
        confidence: 0.6,
        content_type: 'post'
      }
    end

    nil
  end

  def self.analyze_twitter_content(content)
    # Check for engagement elements
    engagement_words = ['?', '!', 'RT', 'via', '@']
    if !engagement_words.any? { |word| content.include?(word) }
      return {
        topic: 'Engagement',
        suggestion: 'Add questions or exclamation points to increase engagement. Consider tagging relevant accounts.',
        confidence: 0.75,
        content_type: 'post'
      }
    end

    # Check for trending topics or hashtags
    if content.scan(/#\w+/).empty?
      return {
        topic: 'Trending Topics',
        suggestion: 'Consider adding relevant hashtags to join trending conversations.',
        confidence: 0.65,
        content_type: 'post'
      }
    end

    nil
  end

  def self.analyze_facebook_content(content)
    # Check for community engagement
    community_words = ['community', 'group', 'together', 'share', 'discuss', 'connect']
    if !community_words.any? { |word| content.downcase.include?(word) }
      return {
        topic: 'Community Building',
        suggestion: 'Facebook thrives on community engagement. Consider asking questions or encouraging discussion.',
        confidence: 0.7,
        content_type: 'post'
      }
    end

    # Check for emotional triggers
    emotional_words = ['love', 'amazing', 'excited', 'proud', 'grateful', 'inspiring']
    if !emotional_words.any? { |word| content.downcase.include?(word) }
      return {
        topic: 'Emotional Connection',
        suggestion: 'Posts with emotional elements tend to perform better on Facebook. Consider sharing how you feel.',
        confidence: 0.6,
        content_type: 'post'
      }
    end

    nil
  end

  def self.analyze_tiktok_content(content)
    # TikTok specific suggestions
    tiktok_words = ['trend', 'viral', 'hack', 'tips', 'life', 'daily']
    if !tiktok_words.any? { |word| content.downcase.include?(word) }
      return {
        topic: 'TikTok Trends',
        suggestion: 'TikTok loves trending content. Consider incorporating popular formats or trending topics.',
        confidence: 0.8,
        content_type: 'video'
      }
    end

    # Check for entertainment value
    entertainment_words = ['fun', 'funny', 'cool', 'awesome', 'crazy', 'wild']
    if !entertainment_words.any? { |word| content.downcase.include?(word) }
      return {
        topic: 'Entertainment Value',
        suggestion: 'TikTok is all about entertainment. Make your content more fun and engaging.',
        confidence: 0.75,
        content_type: 'video'
      }
    end

    nil
  end

  def self.auto_save_draft(user, draft_data)
    # Find existing auto-save draft or create new one
    draft = user.draft_contents.find_or_initialize_by(
      title: 'Auto-saved Draft',
      content_type: draft_data[:content_type] || 'post',
      platform: draft_data[:platform] || 'general'
    )

    draft.update!(
      content: draft_data[:content],
      title: draft_data[:title] || "Draft - #{Time.now.strftime('%Y-%m-%d %H:%M')}",
      status: 'draft',
      auto_saved_at: Time.now
    )

    draft
  end

  def self.analyze_content_quality(content, platform)
    analysis = {
      score: 0,
      issues: [],
      suggestions: [],
      strengths: []
    }

    # Basic metrics
    word_count = content.split.length
    char_count = content.length
    sentence_count = content.split(/[.!?]+/).length

    # Calculate base score
    analysis[:score] = 50

    # Length analysis
    if word_count < 10
      analysis[:issues] << 'Content is too short'
      analysis[:score] -= 20
    elsif word_count > 200
      analysis[:issues] << 'Content might be too long'
      analysis[:score] -= 10
    else
      analysis[:strengths] << 'Good content length'
      analysis[:score] += 10
    end

    # Platform-specific checks
    case platform.downcase
    when 'twitter'
      if char_count > 280
        analysis[:issues] << 'Exceeds Twitter character limit'
        analysis[:score] -= 25
      end
      analysis[:suggestions] << 'Consider using Twitter threads for longer content'
    when 'linkedin'
      if word_count < 100
        analysis[:issues] << 'LinkedIn posts perform better with more content'
        analysis[:score] -= 15
      end
    end

    # Engagement elements
    has_question = content.include?('?')
    has_exclamation = content.include?('!')
    has_hashtags = content.scan(/#\w+/).length > 0
    has_mentions = content.scan(/@\w+/).length > 0

    if has_question
      analysis[:strengths] << 'Includes engaging questions'
      analysis[:score] += 5
    end

    if has_hashtags
      analysis[:strengths] << 'Uses hashtags for discoverability'
      analysis[:score] += 5
    else
      analysis[:suggestions] << 'Consider adding relevant hashtags'
    end

    # Clamp score between 0 and 100
    analysis[:score] = [0, [100, analysis[:score]].min].max

    analysis
  end
end