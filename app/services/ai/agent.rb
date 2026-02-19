module Ai
  class Agent
    class NoToolSelectedError < StandardError; end
    
    def initialize(user:, campaign: nil, tools: nil)
      @user = user
      @campaign = campaign
      @tools = tools || ToolRegistry.schema
      @conversation = []
    end
    
    # Main entry point - returns structured tool call hash
    def call(prompt:, system: nil, allow_plain_text: false)
      # Build system message
      system_message = system || default_system_message

      # Inject viral context if campaign has a client
      system_message = inject_viral_context(system_message) if @campaign&.client

      # Track LLM usage for campaign
      estimated_tokens = estimate_tokens(prompt, system_message)
      Ai::UsageTracker.track_llm_tokens(@campaign, estimated_tokens) if @campaign

      # Use LLM service with tool calling
      response = LlmService.new(
        prompt: prompt,
        system: system_message,
        tools: @tools,
        tool_choice: "auto"
      ).call_blocking
      
      # If we got plain text and it's not allowed, raise error
      if response.blank?
        raise NoToolSelectedError, "No response from LLM"
      end
      
      # The response could be:
      # 1. Plain text (if no tools were called)
      # 2. Tool call result (if tools were executed)
      
      # Check if this looks like a tool call response (should have been executed automatically)
      # If we got here with plain text and allow_plain_text is false, we have a problem
      
      # Parse and return structured result
      parse_response(response, allow_plain_text)
    end
    
    # Execute a single tool call and return result
    def execute_tool(tool_name, parameters)
      ToolExecutor.call(tool_name, parameters, user: @user, campaign: @campaign)
    end
    
    private
    
    def default_system_message
      <<~SYSTEM
        You are an autonomous social media campaign manager. Your role is to:
        
        1. Generate engaging social media posts
        2. Create images for posts when needed
        3. Schedule posts for optimal times
        4. Analyze campaign performance
        5. Complete campaigns when goals are met
        
        Use the available tools to accomplish these tasks. Always prefer using tools over plain text responses.
        
        Guidelines:
        - Generate varied content across different themes
        - Use appropriate hashtags for reach
        - Space out posts appropriately
        - Consider the target audience
        - Monitor performance and adapt strategy
      SYSTEM
    end
    
    def parse_response(response, allow_plain_text)
      # Response could contain tool call results or plain text
      # If tools were provided and executed, we'd get the result back
      
      # Check if response looks like tool execution results
      if response.is_a?(Hash) && response[:tool_calls]
        # Return structured tool call
        {
          tool_name: response[:tool_calls].first[:name],
          parameters: response[:tool_calls].first[:arguments],
          raw: response
        }
      elsif response.is_a?(String)
        # Plain text response
        if allow_plain_text
          {
            tool_name: nil,
            parameters: nil,
            content: response,
            raw: response
          }
        else
          # Try to extract any tool-like structure from the text
          extracted = extract_tool_from_text(response)
          if extracted
            extracted.merge(raw: response)
          else
            raise NoToolSelectedError, "Expected tool call but got plain text: #{response[0..100]}..."
          end
        end
      else
        { content: response, raw: response }
      end
    end
    
    def extract_tool_from_text(text)
      # Try to parse as JSON if it looks like tool output
      json_match = text.match(/\{.*\}/m)
      return nil unless json_match
      
      begin
        data = JSON.parse(json_match[0])
        # If it has tool-like keys, return as tool
        if data['tool_name'] || data['action']
          {
            tool_name: data['tool_name'] || data['action'],
            parameters: data['parameters'] || data.except('tool_name', 'action')
          }
        end
      rescue JSON::ParserError
        nil
      end
    end

    def estimate_tokens(prompt, system_message)
      # Rough estimate: ~4 characters per token on average
      total_chars = (prompt.to_s.length + system_message.to_s.length)
      (total_chars / 4.0).ceil
    end

    # Inject viral content context into system message
    def inject_viral_context(system_message)
      viral_context = Analytics::ViralDetector.get_viral_context_for_ai(
        client_id: @campaign.client_id,
        campaign_id: @campaign.id
      )

      return system_message unless viral_context

      <<~SYSTEM
        #{system_message}

        ## Viral Content Context
        #{viral_context}
        
        Use these viral posts as inspiration for new content. Consider:
        - Similar topics and themes
        - Tone and style that resonated
        - Hashtags that performed well
      SYSTEM
    end
  end
end
