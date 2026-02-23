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

    begin
      # Generate the image using the image generation service (class method)
      result = ImageGenerationService.generate_image(prompt: prompt)

      if result[:success]
        image_url = result[:output_url] || result[:task_id]
        Rails.logger.info "[ImageGenerationJob] Image generated successfully: #{image_url}"

        # Save the image URL to the conversation
        message = AiMessage.create!(
          conversation: conversation,
          role: 'assistant',
          content: "I've generated an image based on your request: #{prompt}\n\n![Generated Image](#{image_url})",
          message_type: 'image'
        )

        # Broadcast to the user via ActionCable
        ActionCable.server.broadcast(
          "ai_chat_#{conversation.id}",
          {
            type: 'image_generated',
            image_url: image_url,
            prompt: prompt,
            message_id: message.id
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
