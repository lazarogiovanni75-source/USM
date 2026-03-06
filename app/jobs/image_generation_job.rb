class ImageGenerationJob < ApplicationJob
  queue_as :default

  def perform(conversation_id:, prompt:, user_id:)
    Rails.logger.info "[ImageGenerationJob] Starting image generation for user #{user_id}"

    # Get the conversation and user
    conversation = AiConversation.find_by(id: conversation_id)
    user = User.find_by(id: user_id)

    unless conversation && user
      Rails.logger.error "[ImageGenerationJob] Conversation or user not found"
      return
    end
    
    # Prevent duplicate image generations - check for recent pending images with same prompt
    recent_image = conversation.ai_messages.where(
      "created_at > ? AND role = 'assistant' AND message_type = 'image'", 
      5.minutes.ago
    ).where("content ILIKE ?", "%#{prompt[0..30]}%").first
    
    if recent_image
      Rails.logger.info "[ImageGenerationJob] Duplicate image generation detected, skipping"
      ActionCable.server.broadcast(
        "ai_chat_#{conversation.id}",
        {
          type: 'image_generated',
          image_url: recent_image.content[/!\[([^\]]+)\]\(([^)]+)\)/, 2],
          prompt: prompt,
          message_id: recent_image.id
        }
      )
      return
    end

    begin
      # Generate the image using the image generation service (class method)
      result = ImageGenerationService.generate_image(prompt: prompt)

      if result[:success]
        image_url = result[:output_url] || result[:task_id]
        Rails.logger.info "[ImageGenerationJob] Image generated successfully: #{image_url}"

        # Save the image URL to the conversation
        message = AiMessage.create!(
          ai_conversation: conversation,
          role: 'assistant',
          content: "I've generated an image based on your request: #{prompt}\n\n![Generated Image](#{image_url})",
          message_type: 'image'
        )

        # Also save to Drafts so user can find it at /drafts
        draft = DraftContent.create!(
          user: user,
          title: "AI Image: #{prompt.truncate(50)}",
          content: "![Generated Image](#{image_url})\n\nPrompt: #{prompt}",
          content_type: 'image',
          platform: 'general',
          status: 'draft',
          metadata: {
            image_url: image_url,
            prompt: prompt,
            conversation_id: conversation.id,
            message_id: message.id,
            generated_at: Time.current.iso8601
          }
        )
        Rails.logger.info "[ImageGenerationJob] Image saved to Drafts: #{draft.id}"

        # Broadcast to the user via ActionCable
        ActionCable.server.broadcast(
          "ai_chat_#{conversation.id}",
          {
            type: 'image_generated',
            image_url: image_url,
            prompt: prompt,
            message_id: message.id,
            draft_id: draft.id
          }
        )
      else
        error_msg = result[:error] || 'Failed to generate image'
        Rails.logger.error "[ImageGenerationJob] Image generation failed: #{error_msg}"

        # Notify user of failure
        ActionCable.server.broadcast(
          "ai_chat_#{conversation.id}",
          {
            type: 'error',
            error: "Image generation failed: #{error_msg}"
          }
        )
      end
    rescue ImageGenerationService::ServiceUnavailableError => e
      Rails.logger.error "[ImageGenerationJob] Image generation services unavailable: #{e.message}"
      # Determine user-friendly message based on error
      if e.message.include?('credit') || e.message.include?('unavailable')
        user_message = "Image generation is temporarily unavailable due to service issues. Please try again in a few moments or contact support if the problem persists."
      else
        user_message = "Image generation is temporarily unavailable. Please try again in a few moments, or contact support if the issue persists."
      end
      ActionCable.server.broadcast(
        "ai_chat_#{conversation.id}",
        {
          type: 'error',
          error: user_message
        }
      )
    rescue => e
      Rails.logger.error "[ImageGenerationJob] Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      ActionCable.server.broadcast(
        "ai_chat_#{conversation.id}",
        {
          type: 'error',
          error: "Image generation failed: #{e.message}"
        }
      )
    end
  end
end
