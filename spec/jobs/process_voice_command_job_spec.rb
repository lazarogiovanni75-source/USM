require 'rails_helper'

RSpec.describe ProcessVoiceCommandJob, type: :job do
  describe '#perform' do
    it 'executes successfully' do
      expect {
        ProcessVoiceCommandJob.perform_now
      }.not_to raise_error
    end
  end
end
