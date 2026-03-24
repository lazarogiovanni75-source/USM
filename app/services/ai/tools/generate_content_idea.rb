module Ai
  module Tools
    class GenerateContentIdea
      class Error < StandardError; end
      
      def self.call(user:, campaign: nil, topic:, platform: "any", count: 3, **)
        Rails.logger.info "[Tools::GenerateContentIdea] Generating #{count} ideas for topic: #{topic}, platform: #{platform}"
        
        # Validate inputs
        topic = topic.to_s.strip
        raise Error, "Topic is required" if topic.blank?
        
        count = [count.to_i, 1].max
        count = [count, 10].min
        
        platform = platform.to_s.downcase
        platform = "any" if platform.blank?
        
        valid_platforms = %w[twitter facebook instagram linkedin any]
        unless valid_platforms.include?(platform)
          platform = "any"
        end
        
        # Build prompt based on platform
        prompt = build_prompt(topic: topic, platform: platform, count: count)
        
        # Call LLM to generate ideas
        response = LlmService.call_blocking(
          prompt: prompt,
          model: "gpt-4o",
          temperature: 0.8
        )
        
        # Parse response into structured ideas
        ideas = parse_ideas(response, count)
        
        Rails.logger.info "[Tools::GenerateContentIdea] Generated #{ideas.count} ideas successfully"
        
        {
          success: true,
          ideas: ideas,
          topic: topic,
          platform: platform,
          count: ideas.count,
          message: "Successfully generated #{ideas.count} content ideas"
        }
      rescue => e
        Rails.logger.error "[Tools::GenerateContentIdea] Error: #{e.message}"
        { success: false, error: e.message }
      end
      
      def self.build_prompt(topic:, platform:, count:)
        platform_text = platform == "any" ? "various social media platforms" : platform
        
        <<~PROMPT
          Generate #{count} unique and engaging social media content ideas about "#{topic}" for #{platform_text}.
          
          For each idea, provide:
          1. A catchy title/hook (max 10 words)
          2. The main content (tweet-length for Twitter, 1-2 sentences for others)
          3. 2-4 relevant hashtags
          
          Format your response as a JSON array of objects with keys: title, content, hashtags (as an array).
          
          Example format:
          [
            {"title": "Hook here", "content": "Main message here", "hashtags": ["#tag1", "#tag2"]}
          ]
          
          Make the ideas creative, diverse, and actionable. Return ONLY valid JSON array.
        PROMPT
      end
      
      def self.parse_ideas(response, expected_count)
        # Try to parse as JSON
        begin
          ideas = JSON.parse(response)
          
          # Ensure it's an array
          ideas = [ideas] unless ideas.is_a?(Array)
          
          # Validate each idea has required fields
          ideas = ideas.select do |idea|
            idea.is_a?(Hash) && idea["title"].present? && idea["content"].present?
          end.take(expected_count)
          
          return ideas.map do |idea|
            {
              title: idea["title"].to_s,
              content: idea["content"].to_s,
              hashtags: Array(idea["hashtags"]).map(&:to_s)
            }
          end
        rescue JSON::ParserError
          # If JSON parsing fails, create ideas from raw text
          return parse_raw_text(response, expected_count)
        end
        
        # Fallback if no ideas parsed
        if ideas.empty?
          return [{
            title: "#{topic} Content",
            content: response.to_s.truncate(200),
            hashtags: ["#content", "#ideas"]
          }]
        end
        
        ideas
      end
      
      def self.parse_raw_text(response, count)
        # Split by lines or numbered items
        lines = response.split("\n").reject(&:blank?)
        
        ideas = []
        current_idea = {}
        
        lines.each do |line|
          line = line.strip
          next if line.empty?
          
          # Detect title/heading
          if line.match?(/^\d+[\.\)]\s*/) || line.match?(/^title:/i)
            ideas << current_idea if current_idea.present?
            current_idea = { title: line.sub(/^(\d+[\.\)]\s*|title:)/i, "").strip }
          elsif line.match?(/^content:/i)
            current_idea[:content] = line.sub(/^content:/i, "").strip
          elsif line.match?(/^hashtags?:/i)
            current_idea[:hashtags] = line.sub(/^hashtags?:/i, "").split.map(&:strip).select { |t| t.start_with?("#") }
          elsif current_idea.present? && !current_idea[:content]
            current_idea[:content] = line
          end
        end
        
        ideas << current_idea if current_idea.present?
        
        # Ensure we have at least some ideas
        if ideas.empty?
          ideas << {
            title: "Content Ideas for #{topic}",
            content: response.to_s.truncate(200),
            hashtags: ["#content", "#ideas"]
          }
        end
        
        ideas.take(count)
      end
    end
  end
end
