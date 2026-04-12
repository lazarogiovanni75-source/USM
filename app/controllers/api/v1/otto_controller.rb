module Api
  module V1
    class OttoController < ApplicationController
      before_action :authenticate_user!

      def chat
        user_message = params[:message].to_s.strip

        if user_message.blank?
          render json: { error: "Message cannot be blank" }, status: :unprocessable_entity
          return
        end

        # Save the user's message
        current_user.otto_messages.create!(role: "user", content: user_message)

        # Check if this is a task request
        if task_request?(user_message)
          execute_task(user_message)
        else
          # Regular chat - call Anthropic API
          chat_response(user_message)
        end
      rescue => e
        Rails.logger.error "Otto-Pilot error: #{e.message}"
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
          current_user.otto_messages.create!(role: "assistant", content: reply)

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
          current_user.otto_messages.create!(role: "assistant", content: error_reply)
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

          current_user.otto_messages.create!(role: "assistant", content: reply)

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
          current_user.otto_messages.create!(role: "assistant", content: error_reply)
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

          current_user.otto_messages.create!(role: "assistant", content: reply)

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
          current_user.otto_messages.create!(role: "assistant", content: error_reply)
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

          current_user.otto_messages.create!(role: "assistant", content: reply)
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

          current_user.otto_messages.create!(role: "assistant", content: reply)

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
          current_user.otto_messages.create!(role: "assistant", content: error_reply)
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

        reply = "🖼️ Image generation started!\n\n"

        if caption.present?
          reply += "Caption: #{caption.truncate(100)}\n\n"
        end

        reply += "Your image is being created and will be ready shortly.\n"
        reply += "I'll notify you when it's done!"

        reply
      end

      def chat_response(message)
        # Build conversation history (last 20 messages)
        history = current_user.otto_messages.recent.map do |msg|
          { role: msg.role, content: msg.content }
        end

        # Call Anthropic API
        client = Anthropic::Client.new(api_key: ENV["ANTHROPIC_API_KEY"])

        response = client.messages(
          model: "claude-sonnet-4-20250514",
          max_tokens: 1024,
          system: otto_system_prompt,
          messages: history
        )

        assistant_reply = response.content.first.text

        # Save assistant reply
        current_user.otto_messages.create!(role: "assistant", content: assistant_reply)

        render json: { reply: assistant_reply }
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
          - Executing tasks: generating images, creating videos, posting to social media, scheduling content

          When users ask you to create content, generate images, make posts, or schedule content, you should execute these tasks directly. Use the task execution endpoint to perform these actions.

          You are friendly, concise, and encouraging. You speak like a knowledgeable social media expert and marketing strategist. Keep responses clear and actionable. When generating content, always provide ready-to-use copy the user can post directly.

          The user's name is #{current_user.name rescue 'there'}.
        PROMPT
      end
    end
  end
end
