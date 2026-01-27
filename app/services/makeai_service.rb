class MakeaiService < ApplicationService
  def initialize(post = nil)
    @post = post
  end

  def call
    # Default action - delegate to publish_to_platform
    publish_to_platform
  end

  def publish_to_platform
    return false unless @post.present? && @post.content.present?
    
    platform = @post.platform || @post.content.platform
    
    case platform.downcase
    when 'instagram'
      publish_to_instagram
    when 'twitter', 'x'
      publish_to_twitter
    when 'linkedin'
      publish_to_linkedin
    when 'facebook'
      publish_to_facebook
    when 'tiktok'
      publish_to_tiktok
    else
      Rails.logger.warn "Unsupported platform: #{platform}"
      false
    end
  end

  private

  def publish_to_instagram
    begin
      # Check if post has images
      if @post.content.images.attached?
        # Instagram API with images
        image_urls = @post.content.images.map { |image| Rails.application.routes.default_url_options[:host] + Rails.application.routes.url_helpers.rails_blob_url(image) }
        result = post_to_instagram_api(image_urls.first, @post.content.body)
      else
        # Instagram API with text-only post
        result = post_to_instagram_api(nil, @post.content.body)
      end
      
      if result[:success]
        @post.update!(status: 'published', posted_at: Time.current, platform_post_id: result[:post_id])
        true
      else
        @post.update!(status: 'failed', error_message: result[:error])
        false
      end
    rescue => e
      Rails.logger.error "Instagram posting failed: #{e.message}"
      @post.update!(status: 'failed', error_message: e.message)
      false
    end
  end

  def publish_to_twitter
    begin
      tweet_text = truncate_text(@post.content.body, 280)
      result = post_to_twitter_api(tweet_text)
      
      if result[:success]
        @post.update!(status: 'published', posted_at: Time.current, platform_post_id: result[:post_id])
        true
      else
        @post.update!(status: 'failed', error_message: result[:error])
        false
      end
    rescue => e
      Rails.logger.error "Twitter posting failed: #{e.message}"
      @post.update!(status: 'failed', error_message: e.message)
      false
    end
  end

  def publish_to_linkedin
    begin
      # LinkedIn supports longer posts
      post_text = @post.content.body
      result = post_to_linkedin_api(post_text)
      
      if result[:success]
        @post.update!(status: 'published', posted_at: Time.current, platform_post_id: result[:post_id])
        true
      else
        @post.update!(status: 'failed', error_message: result[:error])
        false
      end
    rescue => e
      Rails.logger.error "LinkedIn posting failed: #{e.message}"
      @post.update!(status: 'failed', error_message: e.message)
      false
    end
  end

  def publish_to_facebook
    begin
      post_text = @post.content.body
      result = post_to_facebook_api(post_text)
      
      if result[:success]
        @post.update!(status: 'published', posted_at: Time.current, platform_post_id: result[:post_id])
        true
      else
        @post.update!(status: 'failed', error_message: result[:error])
        false
      end
    rescue => e
      Rails.logger.error "Facebook posting failed: #{e.message}"
      @post.update!(status: 'failed', error_message: e.message)
      false
    end
  end

  def publish_to_tiktok
    begin
      # TikTok requires video content
      if @post.content.videos.attached?
        video_url = Rails.application.routes.default_url_options[:host] + Rails.application.routes.url_helpers.rails_blob_url(@post.content.videos.first)
        result = post_to_tiktok_api(video_url, @post.content.body)
        
        if result[:success]
          @post.update!(status: 'published', posted_at: Time.current, platform_post_id: result[:post_id])
          true
        else
          @post.update!(status: 'failed', error_message: result[:error])
          false
        end
      else
        @post.update!(status: 'failed', error_message: 'TikTok requires video content')
        false
      end
    rescue => e
      Rails.logger.error "TikTok posting failed: #{e.message}"
      @post.update!(status: 'failed', error_message: e.message)
      false
    end
  end

  # API Methods (mock implementations - replace with actual API calls)
  def post_to_instagram_api(image_url, caption)
    # Mock Instagram API call
    # In production, this would use Instagram Basic Display API or Instagram Graph API
    
    # Simulate API delay
    sleep rand(0.5..2.0)
    
    # Mock success/failure
    if rand > 0.1 # 90% success rate
      {
        success: true,
        post_id: "ig_#{SecureRandom.hex(8)}",
        post_url: "https://instagram.com/p/mock_post_123"
      }
    else
      {
        success: false,
        error: 'API rate limit exceeded'
      }
    end
  end

  def post_to_twitter_api(text)
    # Mock Twitter API call
    # In production, this would use Twitter API v2
    
    sleep rand(0.3..1.0)
    
    if rand > 0.05 # 95% success rate
      {
        success: true,
        post_id: "tweet_#{SecureRandom.hex(6)}",
        post_url: "https://twitter.com/user/status/mock_tweet_123"
      }
    else
      {
        success: false,
        error: 'Tweet content violates Twitter policy'
      }
    end
  end

  def post_to_linkedin_api(text)
    # Mock LinkedIn API call
    # In production, this would use LinkedIn API
    
    sleep rand(0.4..1.5)
    
    if rand > 0.08 # 92% success rate
      {
        success: true,
        post_id: "li_#{SecureRandom.hex(8)}",
        post_url: "https://linkedin.com/feed/update/mock_post_123"
      }
    else
      {
        success: false,
        error: 'LinkedIn posting quota exceeded'
      }
    end
  end

  def post_to_facebook_api(text)
    # Mock Facebook API call
    # In production, this would use Facebook Graph API
    
    sleep rand(0.5..1.8)
    
    if rand > 0.12 # 88% success rate
      {
        success: true,
        post_id: "fb_#{SecureRandom.hex(8)}",
        post_url: "https://facebook.com/mock_post_123"
      }
    else
      {
        success: false,
        error: 'Facebook content requires approval'
      }
    end
  end

  def post_to_tiktok_api(video_url, caption)
    # Mock TikTok API call
    # In production, this would use TikTok for Developers API
    
    sleep rand(1.0..3.0)
    
    if rand > 0.15 # 85% success rate (lower due to video processing)
      {
        success: true,
        post_id: "tt_#{SecureRandom.hex(10)}",
        post_url: "https://tiktok.com/@user/video/mock_video_123"
      }
    else
      {
        success: false,
        error: 'TikTok video processing failed'
      }
    end
  end

  def truncate_text(text, max_length)
    if text.length <= max_length
      text
    else
      text[0...max_length - 3] + '...'
    end
  end
end
