module Ai
  module Tools
    class GeneratePost
      class Error < StandardError; end
      
      def self.call(user:, campaign: nil, platform:, content_type: "text", theme:, tone: "professional", call_to_action: nil, **)
        Rails.logger.info "[Tools::GeneratePost] Generating post for #{platform}, theme: #{theme}"
        
        # Generate caption using LLM
        caption = generate_caption(theme: theme, platform: platform, tone: tone, call_to_action: call_to_action)
        
        # Generate hashtags
        hashtags = generate_hashtags(theme: theme, platform: platform)
        
        # Create draft content
        content = Content.create!(
          user: user,
          title: "#{theme.titleize} - #{platform.titleize}",
          body: "#{caption}\n\n#{hashtags}",
          content_type: content_type,
          platform: platform,
          status: :draft,
          campaign: campaign
        )
        
        Rails.logger.info "[Tools::GeneratePost] Created content ##{content.id}"
        
        {
          success: true,
          content_id: content.id,
          caption: caption,
          hashtags: hashtags,
          platform: platform,
          content_type: content_type,
          message: "Draft post created successfully"
        }
      rescue => e
        Rails.logger.error "[Tools::GeneratePost] Error: #{e.message}"
        { success: false, error: e.message }
      end
      
      def self.generate_caption(theme:, platform:, tone:, call_to_action:)
        prompt = <<~PROMPT
          Write a social media caption for #{platform}.
          
          Theme: #{theme}
          Tone: #{tone}
          #{call_action ? "Call to action: #{call_action}" : ""}
          
          Keep it engaging and within character limits for #{platform}.
          Return ONLY the caption text, no explanations.
        PROMPT
        
        response = LlmService.new(prompt: prompt).call_blocking
        response.strip
      rescue => e
        Rails.logger.warn "[Tools::GeneratePost] Caption generation failed: #{e.message}"
        "Check out our latest content about #{theme}! #{call_action || '#socialmedia'}"
      end
      
      def self.generate_hashtags(theme:, platform:)
        prompt = <<~PROMPT
          Generate 5-10 relevant hashtags for a #{platform} post about "#{theme}".
          Return only hashtags separated by spaces, no other text.
        PROMPT
        
        response = LlmService.new(prompt: prompt).call_blocking
        response.strip
      rescue => e
        Rails.logger.warn "[Tools::GeneratePost] Hashtag generation failed: #{e.message}"
        "##{theme.gsub(' ', '')} #{platform}"
      end
    end
  end
end
