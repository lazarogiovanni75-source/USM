# frozen_string_literal: true

# Agent::Orchestrator - Agentic AI with Claude Opus
#
# This is the agentic brain that replaces simple ChatGPT Q&A.
# It uses Claude opus-4-5 with a looping structure where the AI can:
# - Call tools to generate images/videos (AtlasCloud)
# - Post to social media (Postforme)
# - Fetch analytics (Postforme)
# - Keep looping until the goal is complete
#
# Usage:
#   Agent::Orchestrator.new.run("Create a marketing post with an image about coffee")
#   Agent::Orchestrator.new(user: current_user).run("Post this to Instagram")
#
module Agent
  class Orchestrator
    class AgentError < StandardError; end
    class ToolExecutionError < AgentError; end

    SYSTEM_PROMPT = <<~PROMPT
      You are an AI marketing agent for a social media management platform.
      
      Your capabilities:
      - Generate high-quality images using AI (AtlasCloud)
      - Generate videos from text or images (AtlasCloud)
      - Post content to social media platforms (Postforme)
      - Fetch analytics and performance metrics (Postforme)
      
      When a user asks you to do something:
      1. Break down the request into steps
      2. Use the available tools to accomplish each step
      3. Keep working until the goal is complete
      4. Provide clear status updates about what you're doing
      
      Always be proactive and complete the full request. If the user asks you to
      "create and post" something, do both steps. Don't stop halfway.
      
      When using tools:
      - For images: Use generate_image with a detailed prompt
      - For videos: Use generate_video with a detailed prompt
      - For posting: Use post_to_social with caption and media URLs
      - For analytics: Use fetch_analytics to get performance data
      
      Be helpful, efficient, and complete tasks fully.
    PROMPT

    # Define tools in Anthropic's expected format
    TOOLS = [
      {
        name: 'generate_image',
        description: 'Generate an AI image using AtlasCloud. Returns a task_id that you can poll for the result.',
        input_schema: {
          type: 'object',
          properties: {
            prompt: {
              type: 'string',
              description: 'Detailed description of the image to generate. Be specific and descriptive.'
            },
            model: {
              type: 'string',
              description: 'Image model to use',
              enum: ['black-forest-labs/flux-1.1-pro', 'black-forest-labs/flux-1-pro', 'black-forest-labs/flux-schnell'],
              default: 'black-forest-labs/flux-1.1-pro'
            },
            aspect_ratio: {
              type: 'string',
              description: 'Image aspect ratio',
              enum: ['1:1', '16:9', '9:16', '4:3', '3:4'],
              default: '1:1'
            }
          },
          required: ['prompt']
        }
      },
      {
        name: 'generate_video',
        description: 'Generate an AI video from text using AtlasCloud. Returns a task_id that you can poll for the result.',
        input_schema: {
          type: 'object',
          properties: {
            prompt: {
              type: 'string',
              description: 'Detailed description of the video to generate. Be specific about motion and scene.'
            },
            model: {
              type: 'string',
              description: 'Video model to use',
              enum: ['atlascloud/magi-1-24b'],
              default: 'atlascloud/magi-1-24b'
            },
            aspect_ratio: {
              type: 'string',
              description: 'Video aspect ratio',
              enum: ['16:9', '9:16', '1:1'],
              default: '16:9'
            },
            duration: {
              type: 'integer',
              description: 'Video duration in seconds',
              default: 5
            }
          },
          required: ['prompt']
        }
      },
      {
        name: 'post_to_social',
        description: 'Post content to social media via Postforme. Can include text caption and media (images/videos).',
        input_schema: {
          type: 'object',
          properties: {
            caption: {
              type: 'string',
              description: 'The text caption/content for the post'
            },
            media_urls: {
              type: 'array',
              description: 'Array of media URLs (images or videos) to include in the post',
              items: {
                type: 'string'
              }
            },
            platform: {
              type: 'string',
              description: 'Target platform (if specific)',
              enum: ['instagram', 'twitter', 'facebook', 'linkedin', 'all']
            },
            schedule_time: {
              type: 'string',
              description: 'ISO 8601 datetime to schedule the post (optional, posts immediately if not provided)'
            }
          },
          required: ['caption']
        }
      },
      {
        name: 'fetch_analytics',
        description: 'Fetch analytics and performance metrics from Postforme for social media accounts.',
        input_schema: {
          type: 'object',
          properties: {
            account_id: {
              type: 'string',
              description: 'Specific social account ID to fetch analytics for (optional)'
            },
            post_id: {
              type: 'string',
              description: 'Specific post ID to fetch analytics for (optional)'
            },
            platform: {
              type: 'string',
              description: 'Filter by platform',
              enum: ['instagram', 'twitter', 'facebook', 'linkedin']
            }
          },
          required: []
        }
      },
      {
        name: 'check_task_status',
        description: 'Check the status of an AtlasCloud image or video generation task. Use this to poll for completion.',
        input_schema: {
          type: 'object',
          properties: {
            task_id: {
              type: 'string',
              description: 'The task_id returned from generate_image or generate_video'
            },
            task_type: {
              type: 'string',
              description: 'Type of task',
              enum: ['image', 'video'],
              default: 'image'
            }
          },
          required: ['task_id', 'task_type']
        }
      }
    ].freeze

    attr_reader :user, :conversation_history

    def initialize(user: nil, max_iterations: 10)
      @user = user
      @max_iterations = max_iterations
      @conversation_history = []
      @atlas_image_service = AtlasCloudImageService.new
      @atlas_video_service = AtlasCloudService.new
      @postforme_service = PostformeService.new
    end

    # Main entry point - run the agent with a user message
    #
    # @param user_message [String] The user's request/message
    # @return [String] The agent's final response
    def run(user_message)
      raise AgentError, "User message cannot be blank" if user_message.blank?

      Rails.logger.info "[Agent::Orchestrator] Starting agent run with message: #{user_message[0..100]}"

      # Initialize conversation with user message
      @conversation_history = [{ role: 'user', content: user_message }]

      # Run the agentic loop
      iteration = 0
      final_response = nil

      loop do
        iteration += 1
        
        if iteration > @max_iterations
          Rails.logger.warn "[Agent::Orchestrator] Max iterations (#{@max_iterations}) reached"
          return "I've reached my iteration limit. Here's what I've done so far..."
        end

        Rails.logger.info "[Agent::Orchestrator] Iteration #{iteration}/#{@max_iterations}"

        # Call Claude with current conversation + tools
        response = call_claude

        # Add assistant response to history
        @conversation_history << response

        # Check if Claude wants to use tools
        if response[:content].is_a?(Array)
          tool_uses = response[:content].select { |block| block['type'] == 'tool_use' }
          
          if tool_uses.any?
            Rails.logger.info "[Agent::Orchestrator] Claude wants to use #{tool_uses.length} tool(s)"
            
            # Execute tools and add results to conversation
            tool_results = execute_tools(tool_uses)
            @conversation_history << {
              role: 'user',
              content: tool_results
            }
            
            # Continue loop to let Claude process tool results
            next
          end
        end

        # No more tool calls - extract final text response
        final_response = extract_text_from_response(response)
        break
      end

      Rails.logger.info "[Agent::Orchestrator] Agent run complete after #{iteration} iteration(s)"
      final_response
    rescue => e
      Rails.logger.error "[Agent::Orchestrator] Error: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      "I encountered an error: #{e.message}. Please try again or rephrase your request."
    end

    private

    # Call Claude API with current conversation
    def call_claude
      require 'net/http'
      require 'json'

      uri = URI("#{ENV.fetch('ANTHROPIC_BASE_URL', 'https://api.anthropic.com')}/v1/messages")
      
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request['x-api-key'] = ENV.fetch('ANTHROPIC_API_KEY')
      request['anthropic-version'] = '2023-06-01'

      body = {
        model: 'claude-opus-4-20250514',  # Claude Opus 4.5
        max_tokens: 4096,
        system: SYSTEM_PROMPT,
        messages: @conversation_history,
        tools: TOOLS
      }

      request.body = body.to_json

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 120) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise AgentError, "Claude API error: #{response.code} - #{response.body}"
      end

      parsed = JSON.parse(response.body)
      
      # Return in format: { role: 'assistant', content: [...] }
      {
        role: parsed['role'],
        content: parsed['content']
      }
    end

    # Execute all tool calls and return results
    def execute_tools(tool_uses)
      tool_uses.map do |tool_use|
        tool_name = tool_use['name']
        tool_id = tool_use['id']
        tool_input = tool_use['input']

        Rails.logger.info "[Agent::Orchestrator] Executing tool: #{tool_name} with input: #{tool_input.inspect}"

        begin
          result = execute_single_tool(tool_name, tool_input)
          
          {
            type: 'tool_result',
            tool_use_id: tool_id,
            content: result.to_json
          }
        rescue => e
          Rails.logger.error "[Agent::Orchestrator] Tool execution error: #{e.message}"
          
          {
            type: 'tool_result',
            tool_use_id: tool_id,
            content: JSON.generate({ error: e.message }),
            is_error: true
          }
        end
      end
    end

    # Execute a single tool call
    def execute_single_tool(tool_name, input)
      case tool_name
      when 'generate_image'
        execute_generate_image(input)
      when 'generate_video'
        execute_generate_video(input)
      when 'post_to_social'
        execute_post_to_social(input)
      when 'fetch_analytics'
        execute_fetch_analytics(input)
      when 'check_task_status'
        execute_check_task_status(input)
      else
        raise ToolExecutionError, "Unknown tool: #{tool_name}"
      end
    end

    # Tool: Generate Image
    def execute_generate_image(input)
      result = @atlas_image_service.generate_image(
        prompt: input['prompt'],
        model: input['model'] || 'black-forest-labs/flux-1.1-pro',
        aspect_ratio: input['aspect_ratio'] || '1:1'
      )

      {
        success: true,
        task_id: result['task_id'],
        status: result['status'],
        message: "Image generation started. Use check_task_status with task_id to poll for completion."
      }
    end

    # Tool: Generate Video
    def execute_generate_video(input)
      result = @atlas_video_service.generate_video_from_text(
        prompt: input['prompt'],
        model: input['model'] || 'atlascloud/magi-1-24b',
        aspect_ratio: input['aspect_ratio'] || '16:9',
        duration: input['duration'] || 5
      )

      {
        success: true,
        task_id: result['task_id'],
        status: result['status'],
        message: "Video generation started. Use check_task_status with task_id to poll for completion."
      }
    end

    # Tool: Post to Social Media
    def execute_post_to_social(input)
      # Get user's social accounts
      unless @user
        return {
          success: false,
          error: "No user context available. Cannot post to social media."
        }
      end

      # Get connected social accounts for this user
      social_accounts = @user.social_accounts.connected
      
      if social_accounts.empty?
        return {
          success: false,
          error: "No connected social accounts found. Please connect your social media accounts first."
        }
      end

      # Filter by platform if specified
      if input['platform'].present? && input['platform'] != 'all'
        social_accounts = social_accounts.where(platform: input['platform'])
      end

      account_ids = social_accounts.pluck(:postforme_profile_id).compact

      if account_ids.empty?
        return {
          success: false,
          error: "No Postforme profile IDs found for your accounts."
        }
      end

      # Build media array if provided
      media = nil
      if input['media_urls'].present?
        media = input['media_urls'].map { |url| { url: url } }
      end

      # Create post via Postforme
      options = {}
      options[:media] = media if media.present?
      options[:scheduled_at] = input['schedule_time'] if input['schedule_time'].present?
      options[:now] = true unless input['schedule_time'].present?

      result = @postforme_service.create_post(
        account_ids,
        input['caption'],
        options
      )

      {
        success: true,
        post_id: result.dig('data', 'id'),
        accounts_posted: account_ids.length,
        message: "Post created successfully!"
      }
    rescue => e
      {
        success: false,
        error: "Failed to post: #{e.message}"
      }
    end

    # Tool: Fetch Analytics
    def execute_fetch_analytics(input)
      if input['post_id'].present?
        # Get analytics for specific post
        result = @postforme_service.post_analytics(input['post_id'])
        
        {
          success: true,
          analytics: result['data'],
          message: "Fetched analytics for post #{input['post_id']}"
        }
      elsif input['account_id'].present?
        # Get metrics for specific account
        result = @postforme_service.account_metrics(input['account_id'])
        
        {
          success: true,
          metrics: result['data'],
          message: "Fetched metrics for account #{input['account_id']}"
        }
      else
        # Get all accounts with metrics
        unless @user
          return {
            success: false,
            error: "No user context available. Cannot fetch analytics."
          }
        end

        accounts = @postforme_service.social_accounts
        
        {
          success: true,
          accounts: accounts['data'],
          message: "Fetched all social accounts with available metrics"
        }
      end
    rescue => e
      {
        success: false,
        error: "Failed to fetch analytics: #{e.message}"
      }
    end

    # Tool: Check Task Status
    def execute_check_task_status(input)
      service = input['task_type'] == 'video' ? @atlas_video_service : @atlas_image_service
      
      result = if input['task_type'] == 'video'
        service.video_status(input['task_id'])
      else
        service.image_status(input['task_id'])
      end

      {
        success: true,
        status: result['status'],
        output: result['output'],
        progress: result['progress'],
        error: result['error'],
        message: "Task status: #{result['status']}"
      }
    rescue => e
      {
        success: false,
        error: "Failed to check status: #{e.message}"
      }
    end

    # Extract text content from Claude's response
    def extract_text_from_response(response)
      content = response[:content]
      
      if content.is_a?(Array)
        text_blocks = content.select { |block| block['type'] == 'text' }
        text_blocks.map { |block| block['text'] }.join("\n")
      elsif content.is_a?(String)
        content
      else
        "No response text available"
      end
    end
  end
end
