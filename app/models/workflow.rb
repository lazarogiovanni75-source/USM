class Workflow < ApplicationRecord
  belongs_to :user
  has_many :workflow_steps, dependent: :destroy

  enum status: {
    pending: 'pending',
    running: 'running',
    completed: 'completed',
    failed: 'failed',
    cancelled: 'cancelled'
  }

  enum workflow_type: {
    content_to_image_post: 'content_to_image_post',
    content_to_video_post: 'content_to_video_post',
    content_to_post: 'content_to_post'
  }

  validates :workflow_type, presence: true

  # Create and start a new workflow
  def self.create_and_start(user:, workflow_type:, params: {})
    workflow = create!(
      user: user,
      workflow_type: workflow_type,
      params: params,
      status: :pending
    )

    # Create initial step
    workflow.workflow_steps.create!(
      step_type: 'start',
      status: 'completed',
      order: 0
    )

    workflow
  end

  # Get current step
  def current_step
    workflow_steps.order(order: :asc).find_by(status: 'running')
  end

  # Get next step order
  def next_step_order
    workflow_steps.maximum(:order).to_i + 1
  end

  # Mark step complete and create next
  def complete_step(step_type:, status: 'completed', output: {})
    step = current_step
    step.update!(status: status, output: output) if step

    case step_type
    when 'generate_content'
      create_next_step('generate_media', 'pending')
    when 'generate_media'
      create_next_step('schedule_post', 'pending')
    when 'schedule_post'
      update!(status: 'completed')
    end
  end

  private

  def create_next_step(step_type, status)
    workflow_steps.create!(
      step_type: step_type,
      status: status,
      order: next_step_order
    )
  end
end
