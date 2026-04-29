# frozen_string_literal: true

class SocialListeningService
  PLATFORMS = %w[instagram facebook twitter linkedin tiktok youtube pinterest threads snapchat].freeze
  SENTIMENT_LABELS = { positive: 'positive', negative: 'negative', neutral: 'neutral' }.freeze

  class << self
    # Listen for mentions across platforms based on keywords
    def listen_for_keywords(keywords, options = {})
      platform = options[:platform]
      sentiment_only = options[:sentiment_only] || false

      results = []

      platforms_to_search = platform.present? ? [platform] : PLATFORMS

      platforms_to_search.each do |p|
        begin
          mentions = search_platform_mentions(keywords, p)
          results.concat(mentions)
        rescue StandardError => e
          Rails.logger.warn "[SocialListening] Search failed for #{p}: #{e.message}"
        end
      end

      # Analyze sentiment for each mention
      results.each do |mention|
        mention[:sentiment] = analyze_sentiment(mention[:content])
        mention[:sentiment_score] = calculate_sentiment_score(mention[:sentiment])
      end

      if sentiment_only
        results.select { |r| r[:sentiment] != 'neutral' }
      else
        results
      end
    end

    # Track brand mentions
    def track_brand_mentions(brand_name, options = {})
      keywords = [brand_name, brand_name.downcase, brand_name.gsub(' ', '')]

      # Also add common variations
      keywords << "#{brand_name}Official"
      keywords << "#{brand_name}HQ"
      keywords << "#{brand_name}app"

      listen_for_keywords(keywords, options)
    end

    # Monitor competitor mentions
    def monitor_competitor_mentions(competitor_name)
      keywords = [
        competitor_name,
        competitor_name.downcase,
        "@#{competitor_name.downcase.gsub(' ', '')}"
      ]

      listen_for_keywords(keywords, platform: nil)
    end

    # Track hashtags
    def track_hashtags(hashtags, options = {})
      normalized_tags = hashtags.map do |tag|
        tag.start_with?('#') ? tag : "##{tag}"
      end

      listen_for_keywords(normalized_tags, options)
    end

    # Create alerts for mentions
    def create_alerts(user, mentions, alert_type)
      alerts_created = 0

      mentions.each do |mention|
        next if should_skip_mention?(mention)

        alert = create_alert(user, mention, alert_type)
        alerts_created += 1 if alert
      end

      { success: true, alerts_created: alerts_created }
    end

    # Analyze sentiment of text
    def analyze_sentiment(text)
      return 'neutral' if text.blank?

      # Use LLM for sentiment analysis
      prompt = "Analyze the sentiment of this text and respond with only one word: 'positive', 'negative', or 'neutral'.\n\nText: #{text.truncate(500)}"

      result = LlmService.generate_content(prompt: prompt)
      sentiment = (result[:content] || result[:body] || 'neutral').strip.downcase

      # Validate response
      if SENTIMENT_LABELS.value?(sentiment)
        sentiment
      else
        # Fallback to keyword-based analysis
        keyword_sentiment(text)
      end
    rescue StandardError
      keyword_sentiment(text)
    end

    # Calculate sentiment score (-1 to 1)
    def calculate_sentiment_score(sentiment)
      case sentiment
      when 'positive' then 0.7 + rand * 0.3
      when 'negative' then -0.7 - rand * 0.3
      else 0.0
      end
    end

    # Get trending topics based on keywords
    def get_trending_topics(keywords, days = 7)
      since = days.days.ago

      mentions = SocialListeningMention
                 .where('mentioned_at > ?', since)
                 .where(keyword: keywords)
                 .order(mentioned_at: :desc)

      # Group by day and sentiment
      {
        total_mentions: mentions.count,
        positive_count: mentions.where(sentiment: 'positive').count,
        negative_count: mentions.where(sentiment: 'negative').count,
        neutral_count: mentions.where(sentiment: 'neutral').count,
        daily_breakdown: group_by_day(mentions),
        top_keywords: get_top_keywords(mentions)
      }
    end

    # Get alerts for a user
    def get_user_alerts(user, options = {})
      scope = user.social_listening_alerts

      # Filter by sentiment
      if options[:sentiment].present?
        scope = scope.where(sentiment: options[:sentiment])
      end

      # Filter by alert type
      if options[:alert_type].present?
        scope = scope.where(alert_type: options[:alert_type])
      end

      # Filter by read status
      if options[:unread_only]
        scope = scope.where(read_at: nil)
      end

      # Limit results
      scope.order(created_at: :desc).limit(options[:limit] || 50)
    end

    # Mark alerts as read
    def mark_alerts_read(alert_ids)
      SocialListeningAlert.where(id: alert_ids)
                         .where(read_at: nil)
                         .update_all(read_at: Time.current)

      { success: true, marked_count: alert_ids.count }
    end

    private

    def search_platform_mentions(keywords, platform)
      results = []

      # Simulated search - in production would use platform-specific APIs
      keywords.each do |keyword|
        1.times do
          results << {
            platform: platform,
            keyword: keyword,
            content: generate_sample_mention(keyword, platform),
            author_handle: "@user#{rand(1000..9999)}",
            author_name: Faker::Name.name,
            author_followers: rand(100..50000),
            post_url: "https://#{platform}.com/post/#{rand(100000..999999)}",
            likes_count: rand(0..5000),
            comments_count: rand(0..500),
            shares_count: rand(0..1000),
            mentioned_at: rand(7).days.ago,
            is_verified: rand > 0.7,
            sentiment: nil, # Will be calculated later
            sentiment_score: nil
          }
        end
      end

      results
    rescue StandardError
      []
    end

    def generate_sample_mention(keyword, platform)
      templates = [
        "Just discovered #{keyword}! Amazing product 💯",
        "Does anyone have experience with #{keyword}?",
        "Using #{keyword} for a week now and I love it!",
        "#{keyword} needs to step up their game 👎",
        "Check out what #{keyword} is doing!",
        "My review of #{keyword} after 30 days",
        "Why #{keyword} is the future of social media",
        "Not impressed with #{keyword} lately",
        "Can anyone recommend #{keyword} alternatives?",
        "#{keyword} just announced something exciting!"
      ]

      templates.sample
    end

    def analyze_sentiment(mention)
      # First check for obvious sentiment indicators
      text = mention[:content] || ''

      positive_patterns = [
        /love/i, /amazing/i, /great/i, /excellent/i, /awesome/i,
        /fantastic/i, /perfect/i, /best/i, /incredible/i, /💯/,
        /🔥/i, /❤️/i, /😍/i, /😊/i, /🥰/i
      ]

      negative_patterns = [
        /hate/i, /terrible/i, /awful/i, /worst/i, /bad/i,
        /disappointed/i, /frustrated/i, /annoyed/i, /😠/i,
        /😤/i, /👎/i, /scam/i, /fake/i
      ]

      positive_matches = positive_patterns.count { |p| text.match(p) }
      negative_matches = negative_patterns.count { |p| text.match(p) }

      if positive_matches > negative_matches && positive_matches > 0
        'positive'
      elsif negative_matches > positive_matches && negative_matches > 0
        'negative'
      else
        analyze_sentiment_with_llm(text)
      end
    end

    def analyze_sentiment_with_llm(text)
      prompt = "Sentiment: positive, negative, or neutral?\nText: #{text.truncate(300)}"

      result = LlmService.generate_content(prompt: prompt)
      response = (result[:content] || result[:body] || 'neutral').strip.downcase

      if response.include?('positive')
        'positive'
      elsif response.include?('negative')
        'negative'
      else
        'neutral'
      end
    rescue StandardError
      'neutral'
    end

    def keyword_sentiment(text)
      positive_words = %w[love amazing great excellent awesome fantastic perfect best incredible]
      negative_words = %w[hate terrible awful worst bad disappointed frustrated annoyed]

      pos_count = positive_words.count { |w| text.include?(w) }
      neg_count = negative_words.count { |w| text.include?(w) }

      if pos_count > neg_count
        'positive'
      elsif neg_count > pos_count
        'negative'
      else
        'neutral'
      end
    end

    def create_alert(user, mention, alert_type)
      # Check for duplicate alert
      existing = user.social_listening_alerts.find_by(
        platform: mention[:platform],
        mention_url: mention[:post_url],
        alert_type: alert_type
      )

      return nil if existing

      user.social_listening_alerts.create!(
        platform: mention[:platform],
        keyword: mention[:keyword],
        alert_type: alert_type,
        content: mention[:content],
        author_handle: mention[:author_handle],
        author_name: mention[:author_name],
        author_followers: mention[:author_followers],
        mention_url: mention[:post_url],
        sentiment: mention[:sentiment],
        sentiment_score: mention[:sentiment_score],
        likes_count: mention[:likes_count],
        comments_count: mention[:comments_count],
        is_verified: mention[:is_verified],
        mentioned_at: mention[:mentioned_at]
      )
    rescue StandardError => e
      Rails.logger.warn "[SocialListening] Failed to create alert: #{e.message}"
      nil
    end

    def should_skip_mention?(mention)
      # Skip low engagement from non-verified accounts with few followers
      return true if mention[:author_followers].to_i < 100 && !mention[:is_verified] && (mention[:likes_count] || 0) < 5

      # Skip if already exists
      SocialListeningAlert.exists?(mention_url: mention[:post_url])
    end

    def group_by_day(mentions)
      mentions.group_by { |m| m.mentioned_at.to_date }
              .transform_values(&:count)
              .sort
              .to_h
    end

    def get_top_keywords(mentions)
      keywords = mentions.pluck(:keyword)
      keywords.group_by(&:itself)
              .transform_values(&:count)
              .sort_by { |_, count| -count }
              .first(10)
              .map(&:first)
    end
  end
end