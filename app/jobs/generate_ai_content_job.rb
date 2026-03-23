# Generate AI Content Job - Background job for content generation
class GenerateAiContentJob < ApplicationJob
  queue_as :default

  retry_on AnthropicContentService::ContentGenerationError, wait: :exponentially_longer, attempts: 3

  def perform(content_id)
    content = AiGeneratedContent.find(content_id)

    Rails.logger.info "[GenerateAiContentJob] Starting generation for content ##{content.id}"

    service = AnthropicContentService.new(
      topic: content.topic,
      brand_voice: content.brand_voice,
      platform: content.platform,
      content_type: content.content_type,
      additional_context: content.additional_context
    )

    if content.content_type == 'all'
      result = service.generate_all
      content.update!(
        caption: result[:caption],
        blog_post: result[:blog_post],
        ad_copy: result[:ad_copy],
        hashtags: result[:hashtags],
        thread_story: result[:thread_story],
        email_marketing: result[:email_marketing]
      )
    else
      generated = service.generate
      field_name = content.content_type
      content.update!(field_name => generated) if content.respond_to?("#{field_name}=")
    end

    Rails.logger.info "[GenerateAiContentJob] Completed generation for content ##{content.id}"
  rescue => e
    Rails.logger.error "[GenerateAiContentJob] Error generating content ##{content.id}: #{e.message}"
    raise
  end
end
