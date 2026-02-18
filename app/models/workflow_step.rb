class WorkflowStep < ApplicationRecord
  belongs_to :workflow

  enum step_type: {
    start: 'start',
    generate_content: 'generate_content',
    generate_media: 'generate_media',
    generate_image: 'generate_image',
    generate_video: 'generate_video',
    schedule_post: 'schedule_post',
    publish_now: 'publish_now',
    end: 'end'
  }

  enum status: {
    pending: 'pending',
    running: 'running',
    completed: 'completed',
    failed: 'failed'
  }

  validates :step_type, presence: true

  store :output, accessors: [:content_text, :media_url, :media_type, :post_id, :error_message], coder: JSON
end
