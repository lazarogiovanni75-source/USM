module Api
  module V1
    class OttoController < ApplicationController
      before_action :authenticate_user!
      skip_before_action :verify_authenticity_token

      def chat
        user_message = params[:message].to_s.strip

        if user_message.blank?
          render json: { error: "Message cannot be blank" }, status: :unprocessable_entity
          return
        end

        # Save the user's message (use new + save to avoid validation exceptions)
        msg = current_user.otto_messages.new(role: "user", content: user_message)
        unless msg.save
          Rails.logger.error "[Otto] Failed to save user message: #{msg.errors.full_messages}"
        end

        # Check if this is a task request
        chat_response(user_message)
      rescue => e
        Rails.logger.error "[Otto] Unavailable error: #{e.class} - #{e.message}"
        Rails.logger.error e.backtrace.first(3).join("\n")
        render json: { error: "Otto-Pilot is unavailable right now. Please try again." }, status: :internal_server_error
      end

      def execute
        user_message = params[:message].to_s.strip

        if user_message.blank?
          render json: { error: "Message cannot be blank" }, status: :unprocessable_entity
          return
        end

        execute_task(user_message)
      rescue => e
        Rails.logger.error "Otto-Pilot execute error: #{e.message}"
        render json: { error: "Task execution failed. Please try again." }, status: :internal_server_error
      end

      def draft_status
        draft = current_user.draft_contents.find_by(id: params[:id])

        unless draft
          render json: { error: "Draft not found" }, status: :not_found
          return
        end

        render json: {
          id: draft.id,
          media_url: draft.media_url,
          content: draft.content,
          status: draft.status,
          title: draft.title
        }
      rescue => e
        Rails.logger.error "Draft status error: #{e.message}"
        render json: { error: "Failed to get draft status" }, status: :internal_server_error
      end

      def clear
        current_user.otto_messages.destroy_all
        render json: { success: true }
      end

      def transcribe
        audio_file = params[:audio]

        unless audio_file
          render json: { error: 'No audio file provided' }, status: :unprocessable_entity
          return
        end

        uri = URI("https://api.openai.com/v1/audio/transcriptions")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{ENV['OPENAI_API_KEY']}"

        form_data = [
          ['file', audio_file.tempfile],
          ['model', 'whisper-1']
        ]

        request.set_form form_data, 'multipart/form-data'

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        if response.is_a?(Net::HTTPSuccess)
          render json: JSON.parse(response.body)
        else
          Rails.logger.error "Whisper transcription error: #{response.body}"
          render json: { error: 'Transcription failed. Please try again.' }, status: :unprocessable_entity
        end
      rescue => e
        Rails.logger.error "Transcribe error: #{e.message}"
        render json: { error: 'Transcription failed. Please try again.' }, status: :internal_server_error
      end

      private

      def task_request?(message)
        task_keywords = [
          'generate an image', 'generate image', 'create an image', 'create image',
          'make an image', 'make image', 'generate a video', 'generate video',
          'create a video', 'create video', 'post to', 'post on', 'publish to',
          'publish on', 'schedule a post', 'schedule post', 'share to',
          'create content', 'write content', 'generate content', 'create a post',
          'write a post', 'draft content'
        ]

        message_lower = message.downcase
        task_keywords.any? { |keyword| message_lower.include?(keyword) }
      end

      def execute_task(message)
        message_lower = message.downcase

        # Determine task type
        task_type = detect_task_type(message_lower)

        case task_type
        when 'generate_image'
          generate_image_task(message)
        when 'generate_video'
          generate_video_task(message)
        when 'create_content'
          create_content_task(message)
        when 'post_social'
          post_to_social_task(message)
        else
          # Fall back to chat
          chat_response(message)
        end
      end

      def detect_task_type(message)
        return 'generate_image' if message.match?(/\b(generate|create|make)\b.*\b(image|picture|photo)\b/i)
        return 'generate_video' if message.match?(/\b(generate|create|make)\b.*\bvideo\b/i)
        return 'post_social' if message.match?(/\b(post|publish|share)\b.*\b(to|on)\b/i) ||
                                  message.match?(/\b(to|on)\b.*\b(instagram|facebook|twitter|x|tiktok|linkedin)\b/i)
        return 'create_content' if message.match?(/\b(content|post|caption)\b/) ||
                                    message.match?(/\b(write|generate|create|draft)\b.*\b(post|caption|text)\b/i)
        'unknown'
      end

      def generate_image_task(message)
        # Extract prompt from message
        prompt = extract_prompt(message)

        return chat_response(message) unless prompt.present?

        result = WorkflowService.create_content_with_media(
          user: current_user,
          content_text: prompt,
          generate_image: true,
          generate_video: false
        )

        if result[:success]
          reply = build_image_success_message(result)
          current_user.otto_messages.create(role: "assistant", content: reply)

          render json: {
            reply: reply,
            task: {
              type: 'image',
              draft_id: result[:draft]&.id,
              status: 'processing',
              content_id: result[:content]&.id
            }
          }
        else
          error_reply = "❌ Image generation failed. Please try again with a different prompt."
          current_user.otto_messages.create(role: "assistant", content: error_reply)
          render json: { reply: error_reply, error: true }
        end
      end

      def generate_video_task(message)
        prompt = extract_prompt(message)

        return chat_response(message) unless prompt.present?

        result = WorkflowService.create_content_with_media(
          user: current_user,
          content_text: prompt,
          generate_image: false,
          generate_video: true
        )

        if result[:success]
          reply = "🎬 Video generation started!\n\n"
          reply += "Your video is being created and will be ready in 1-2 minutes.\n"
          reply += "I'll let you know when it's done!"

          current_user.otto_messages.create(role: "assistant", content: reply)

          render json: {
            reply: reply,
            task: {
              type: 'video',
              draft_id: result[:draft]&.id,
              status: 'processing'
            }
          }
        else
          error_reply = "❌ Video generation failed. Please try again."
          current_user.otto_messages.create(role: "assistant", content: error_reply)
          render json: { reply: error_reply, error: true }
        end
      end

      def create_content_task(message)
        prompt = extract_prompt(message)
        prompt ||= message

        result = WorkflowService.create_content_with_media(
          user: current_user,
          content_text: prompt,
          generate_image: false,
          generate_video: false
        )

        if result[:success]
          caption = result[:caption] || "Content created!"
          reply = "✅ Content generated!\n\n"
          reply += "#{caption}\n\n"
          reply += "💡 Check your Drafts to edit or schedule this content."

          current_user.otto_messages.create(role: "assistant", content: reply)

          render json: {
            reply: reply,
            task: {
              type: 'content',
              content_id: result[:content]&.id,
              caption: caption
            }
          }
        else
          error_reply = "❌ Content generation failed. Please try again."
          current_user.otto_messages.create(role: "assistant", content: error_reply)
          render json: { reply: error_reply, error: true }
        end
      end

      def post_to_social_task(message)
        # Extract platform and content from message
        platform = detect_platform(message)
        prompt = extract_prompt(message)

        # Find social account
        social_account = if platform
          current_user.social_accounts.find_by(platform: platform.downcase)
        else
          current_user.social_accounts.first
        end

        unless social_account
          reply = "⚠️ No social account connected.\n\n"
          reply += "Please connect a social media account first:\n"
          reply += "→ Go to Social Accounts → Connect Profile\n\n"
          reply += "Or I can help you generate content to save for later!"

          current_user.otto_messages.create(role: "assistant", content: reply)
          render json: { reply: reply }
          return
        end

        # Generate and post
        result = WorkflowService.create_content_with_media(
          user: current_user,
          content_text: prompt || "Social media post",
          generate_image: false,
          generate_video: false,
          post_now: true,
          social_account_id: social_account.id
        )

        if result[:success]
          platform_name = social_account.platform.titleize
          reply = "🚀 Posted to #{platform_name}!\n\n"
          reply += "Your content has been published.\n"
          reply += "Check your #{platform_name} to see it live!"

          current_user.otto_messages.create(role: "assistant", content: reply)

          render json: {
            reply: reply,
            task: {
              type: 'post',
              platform: platform_name,
              status: 'published'
            }
          }
        else
          error_reply = "❌ Posting failed. Please try again."
          current_user.otto_messages.create(role: "assistant", content: error_reply)
          render json: { reply: error_reply, error: true }
        end
      end

      def extract_prompt(message)
        # Remove common task prefixes to get the actual content prompt
        prompt = message.dup

        # Remove task keywords
        prefixes = [
          'generate an image', 'generate image', 'create an image', 'create image',
          'make an image', 'make image', 'generate a video', 'generate video',
          'create a video', 'create video', 'post to ', 'post on ', 'publish to ',
          'publish on ', 'schedule a post', 'schedule post', 'share to ',
          'create content ', 'write content ', 'generate content ', 'create a post ',
          'write a post ', 'draft content ', 'generate a ', 'create a ', 'make a ',
          'generate ', 'create ', 'make ', 'write ', 'draft '
        ]

        prefixes.each do |prefix|
          if prompt.downcase.start_with?(prefix)
            prompt = prompt[prefix.length..-1].strip
            break
          end
        end

        # Remove platform mentions
        platforms = ['for instagram', 'for facebook', 'for twitter', 'for x', 'for tiktok',
                      'for linkedin', 'for pinterest', 'for bluesky', 'for threads',
                      'on instagram', 'on facebook', 'on twitter', 'on x', 'on tiktok',
                      'on linkedin', 'on pinterest', 'on bluesky', 'on threads']

        platforms.each do |p|
          prompt = prompt.gsub(/#{p}/i, '').strip
        end

        prompt.presence
      end

      def detect_platform(message)
        platforms = {
          'instagram' => ['instagram', 'ig'],
          'facebook' => ['facebook', 'fb'],
          'twitter' => ['twitter', 'x.com', 'x '],
          'tiktok' => ['tiktok', 'tt'],
          'linkedin' => ['linkedin', 'li'],
          'pinterest' => ['pinterest', 'pin'],
          'bluesky' => ['bluesky', 'bsky']
        }

        platforms.each do |platform, keywords|
          return platform if keywords.any? { |k| message.include?(k) }
        end

        nil
      end

      def build_image_success_message(result)
        draft = result[:draft]
        caption = result[:caption]
        reply = "Image generation started!\n\n"

        if caption.present?
          reply += "Caption: #{caption.truncate(100)}\n\n"
        end

        reply += "Your image is being created and will be ready shortly.\n"
        reply += "I'll notify you when it's done!"

        reply
      end

      def chat_response(message)
        Rails.logger.info "[Otto] chat_response called"
        
        begin
          Rails.logger.info "[Otto] chat_response START - message class: #{message.class}, value: #{message.to_s[0..30]}"
          
          # Build conversation history (last 10 messages max)
          history = current_user.otto_messages.order(created_at: :asc).last(10).map do |msg|
            { role: msg.role, content: msg.content }
          end
          Rails.logger.info "[Otto] History built: #{history.length} messages"

          Rails.logger.info "[Otto] Calling Anthropic API with tools..."
          Rails.logger.info "[Otto] Tools being sent: #{otto_tool_definitions.to_json}"
          
          # Call Anthropic API with tool definitions
          client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])

          response = client.messages.create(
            model: "claude-sonnet-4-6",
            max_tokens: 4096,
            system: otto_system_prompt,
            messages: history,
            tools: otto_tool_definitions,
            tool_choice: { "type" => "auto" }
          )

          Rails.logger.info "[Otto] Anthropic response stop_reason: #{response.stop_reason.inspect}"
          Rails.logger.info "[Otto] Anthropic response content count: #{response.content.length}"
          Rails.logger.info "[Otto] Anthropic response content types: #{response.content.map(&:type).inspect}"
          
          # Handle tool_use stop_reason - execute tool and return success message
          if response.stop_reason == "tool_use"
            Rails.logger.info "[Otto] Stop reason is tool_use, processing..."
          end
          
          # Process response - may include text and/or tool_use blocks
          result = process_anthropic_response(response, history)
          render json: { reply: result[:reply].presence || "Done! Let me know if you need anything else." }
        rescue => e
          Rails.logger.error "[Otto] chat_response CRASH: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          raise e
        end
      end

      def process_anthropic_response(response, history)
        text_parts = []
        tool_results = []
        
        # Process each content block in the response
        response.content.each do |block|
          case block.type
          when 'text'
            text_parts << block.text
          when 'tool_use'
            tool_results << { id: block.id, name: block.name, input: block.input }
          end
        end
        
        # Execute tools and return user-friendly message
        if tool_results.any?
          tool_results.each do |tool_call|
            result = execute_otto_tool(tool_call[:name], tool_call[:input])
            
            # Save tool result to history
            current_user.otto_messages.create!(
              role: "user",
              content: "Tool #{tool_call[:name]} result: #{result[:success] ? 'Success' : result[:error]}".to_s
            )
            
            # Return immediate feedback based on tool type
            case tool_call[:name]
            when 'generate_image'
              reply = "⏳ Your image is being generated and will appear in your Drafts shortly!"
            when 'generate_video'
              reply = "🎬 Your video is being generated and will appear in your Drafts shortly!"
            else
              reply = "⏳ Your request is being processed and will appear in your Drafts shortly!"
            end
            
            current_user.otto_messages.create(role: "assistant", content: reply.to_s)
            return { reply: reply }
          end
        end
        
        # If no tools, return text response as normal
        final_reply = text_parts.join("\n")
        
        # Save assistant reply
        current_user.otto_messages.create(role: "assistant", content: final_reply) if final_reply.present?
        
        { reply: final_reply.presence || "I've completed your request!" }
      rescue => e
        Rails.logger.error "[Otto] process_anthropic_response error: #{e.message}"
        { reply: "I encountered an error: #{e.message}" }
      end

      def execute_otto_tool(tool_name, tool_input)
        Rails.logger.info "[Otto] Executing tool: #{tool_name} with input: #{tool_input.inspect}"
        
        case tool_name
        when 'generate_image'
          prompt = tool_input['prompt'] || tool_input[:prompt]
          aspect_ratio = tool_input['aspect_ratio'] || '1:1'
          
          result = AtlasCloudImageService.new.generate_image(
            prompt: prompt,
            aspect_ratio: aspect_ratio
          )
          
          return { success: false, error: "Image service returned nil" } if result.nil?
          
          if result['task_id'].present?
            # Schedule job to poll for completion
            ImagePollJob.perform_later(nil, result['task_id'], 'atlascloud')
            
            # Create draft content
            draft = DraftContent.create(
              user: current_user,
              title: prompt.truncate(50),
              content: prompt,
              content_type: 'image',
              platform: 'general',
              status: 'pending',
              metadata: { 'task_id' => result['task_id'] }
            )
            
            { success: true, message: "Image generation started! Task ID: #{result['task_id']}. You'll be notified when it's ready.", draft_id: draft.id }
          else
            { success: false, error: result['error'] || 'Failed to start image generation' }
          end
        when 'generate_video'
          prompt = tool_input['prompt'] || tool_input[:prompt]
          duration = tool_input['duration'] || 5
          aspect_ratio = tool_input['aspect_ratio'] || '16:9'
          
          result = AtlasCloudService.new.generate_video_from_text(
            prompt: prompt,
            duration: duration,
            aspect_ratio: aspect_ratio
          )
          
          return { success: false, error: "Video service returned nil" } if result.nil?
          
          if result['task_id'].present?
            VideoPollJob.perform_later(nil, result['task_id'], 'atlascloud') if defined?(VideoPollJob)
            { success: true, message: "Video generation started! Task ID: #{result['task_id']}. You'll be notified when it's ready." }
          else
            { success: false, error: result['error'] || 'Failed to start video generation' }
          end
        else
          { success: false, error: "Unknown tool: #{tool_name}" }
        end
      rescue => e
        Rails.logger.error "[Otto] Tool execution error: #{e.message}"
        { success: false, error: e.message }
      end

      def otto_tool_definitions
        [
          {
            "name" => "generate_image",
            "description" => "Generate an AI image. Creates images for social media posts, ads, or any visual content.",
            "input_schema" => {
              "type" => "object",
              "properties" => {
                "prompt" => {
                  "type" => "string",
                  "description" => "Detailed description of the image you want to generate"
                },
                "aspect_ratio" => {
                  "type" => "string",
                  "description" => "Image aspect ratio: 1:1 (square), 16:9 (landscape), 9:16 (portrait)",
                  "enum" => ["1:1", "16:9", "9:16", "4:3", "3:4"]
                }
              },
              "required" => ["prompt"]
            }
          },
          {
            "name" => "generate_video",
            "description" => "Generate an AI video. Creates short videos for social media content.",
            "input_schema" => {
              "type" => "object",
              "properties" => {
                "prompt" => {
                  "type" => "string",
                  "description" => "Description of the video scene and action"
                },
                "duration" => {
                  "type" => "integer",
                  "description" => "Video duration in seconds (5-12)"
                },
                "aspect_ratio" => {
                  "type" => "string",
                  "description" => "Video aspect ratio: 16:9 (landscape) or 9:16 (portrait)",
                  "enum" => ["16:9", "9:16"]
                }
              },
              "required" => ["prompt"]
            }
          }
        ]
      end

      def otto_system_prompt
        <<~PROMPT
          You are Otto-Pilot, an AI assistant built into Ultimate Social Media — an AI-powered social media automation platform.

          You help users with:
          - Writing social media captions, posts, and content for any platform (Instagram, Facebook, TikTok, LinkedIn, X, Pinterest, Bluesky, Threads, YouTube)
          - Suggesting hashtags, hooks, and content ideas
          - Advising on posting strategies and best times to post
          - Helping with brand voice and tone
          - Answering any general questions the user has
          - Explaining how to use features in the app

          When the user requests image or video generation, you MUST use the generate_image or generate_video tools. Do not describe what you would generate — actually call the tool.

          You are friendly, concise, and encouraging. You speak like a knowledgeable social media expert and marketing strategist. Keep responses clear and actionable. When generating content, always provide ready-to-use copy the user can post directly.

          The user's name is #{current_user.name rescue 'there'}.
        PROMPT
      end
    end
  end
end
