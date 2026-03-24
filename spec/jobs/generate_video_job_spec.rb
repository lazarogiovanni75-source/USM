require 'rails_helper'

RSpec.describe GenerateVideoJob, type: :job do
  describe '#perform' do
    it 'executes successfully with valid arguments' do
      # Create a user and video for testing
      user = create(:user)
      video = create(:video, :pending, user: user)

      # Stub the AtlasCloudService to avoid real API calls
      atlas_service_double = instance_double(AtlasCloudService)
      
      # IMPORTANT: The job calls AtlasCloudService.new directly, not through a factory
      # So we need to allow AtlasCloudService to be instantiated and return our double
      allow(AtlasCloudService).to receive(:new).and_return(atlas_service_double)

      # Return the prediction_id on first call (generate_video)
      allow(atlas_service_double).to receive(:generate_video).and_return(
        'prediction_id' => 'pred-123',
        'output' => nil
      )

      # Return success status immediately (avoid polling loop)
      # Also need to handle the status check in wait_for_completion
      allow(atlas_service_double).to receive(:task_status).and_return(
        'status' => 'succeeded',
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
