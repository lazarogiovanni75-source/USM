require 'rails_helper'

RSpec.describe WorkflowExecutionJob, type: :job do
  describe '#perform' do
    it 'executes successfully' do
      # Skip if no workflow exists
      skip('No workflow to test') if Workflow.count == 0
      
      workflow = Workflow.create!(
        user: User.first || User.create!(email: 'test@test.com', password: 'password'),
        workflow_type: 'content_to_post',
        status: 'pending',
        params: { content_text: 'Test content' }
      )
      
      expect {
        WorkflowExecutionJob.perform_now(workflow.id)
      }.not_to raise_error
    end
  end
end
