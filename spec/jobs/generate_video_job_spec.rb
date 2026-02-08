require 'rails_helper'

RSpec.describe GenerateVideoJob, type: :job do
  describe '#perform' do
    it 'executes successfully with valid arguments' do
      # Create a user and video for testing
      user = create(:user)
      video = create(:video, user: user)

      # Stub the SoraService to avoid real API calls
      allow(SoraService).to receive(:new).and_return(
        instance_double(SoraService, generate_video: { 'status' => 'succeeded', 'output' => 'http://example.com/video.mp4' })
      )

      expect {
        GenerateVideoJob.perform_now(video.id, 'test topic')
      }.not_to raise_error
    end
  end
end
