require 'rails_helper'

RSpec.describe GenerateVideoJob, type: :job do
  describe '#perform' do
    it 'executes successfully with valid arguments' do
      # Create a user and video for testing
      user = create(:user)
      video = create(:video, user: user)

      # Stub the SoraService to avoid real API calls
      sora_service_double = instance_double(SoraService)
      allow(SoraService).to receive(:new).and_return(sora_service_double)

      # Return the prediction URL on first call (generate_video)
      allow(sora_service_double).to receive(:generate_video).and_return(
        'status' => 'succeeded',
        'output' => 'http://example.com/video.mp4',
        'urls' => { 'get' => 'http://example.com/prediction/123' }
      )

      # Return succeeded status immediately (avoid polling loop)
      allow(sora_service_double).to receive(:get_prediction).and_return(
        'status' => 'succeeded',
        'output' => 'http://example.com/video.mp4'
      )

      expect {
        GenerateVideoJob.perform_now(video.id, 'test topic')
      }.not_to raise_error

      # Verify video was updated
      video.reload
      expect(video.status).to eq('completed')
      expect(video.video_url).to eq('http://example.com/video.mp4')
    end
  end
end
