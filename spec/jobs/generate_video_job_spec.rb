require 'rails_helper'

RSpec.describe GenerateVideoJob, type: :job do
  describe '#perform' do
    it 'executes successfully with valid arguments' do
      # Create a user and video for testing
      user = create(:user)
      video = create(:video, :pending, user: user)

      # Stub the PoyoService to avoid real API calls
      poyo_service_double = instance_double(PoyoService)
      allow(PoyoService).to receive(:new).and_return(poyo_service_double)

      # Return the task_id on first call (generate_video)
      allow(poyo_service_double).to receive(:generate_video).and_return(
        'task_id' => 'task-123',
        'output' => nil
      )

      # Return success status immediately (avoid polling loop)
      allow(poyo_service_double).to receive(:task_status).and_return(
        'status' => 'success',
        'output' => 'http://example.com/video.mp4'
      )

      expect {
        GenerateVideoJob.perform_now(video.id, 'test topic')
      }.not_to raise_error

      # Verify video was updated
      video.reload
      expect(video.status_completed?).to eq(true)
      expect(video.video_url).to eq('http://example.com/video.mp4')
    end
  end
end
