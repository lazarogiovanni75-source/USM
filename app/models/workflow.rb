class Workflow < ApplicationRecord
  belongs_to :user

  validates :workflow_type, presence: true
  validates :content, presence: true
  before_validation :set_title, if: -> { content.present? && title.blank? }

  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, prefix: true

  # Get the generated image URL, polling Atlas Cloud if needed
  # This handles both old workflows (direct poll) and new workflows (via DraftContent)
  def image_url
    return nil unless result.present?

    result_data = JSON.parse(result)

    # First check if we have a DraftContent with the image
    if result_data['draft_id'].present?
      draft = DraftContent.find_by(id: result_data['draft_id'])
      return draft.media_url if draft&.media_url.present?
    end

    # For old workflows without draft_id, poll Atlas Cloud directly
    if result_data['image_task_id'].present?
      service = result_data['image_service'] == 'atlas_cloud' ? AtlasCloudImageService : nil
      return nil unless service

      begin
        status_response = service.new.image_status(result_data['image_task_id'])
        return status_response['output'] if status_response['status'] == 'success' && status_response['output'].present?
      rescue => e
        Rails.logger.error "Error polling image status: #{e.message}"
        return nil
      end
    end

    nil
  rescue JSON::ParserError
    nil
  end

  private

  def set_title
    self.title = content.truncate(50)
  end
end
