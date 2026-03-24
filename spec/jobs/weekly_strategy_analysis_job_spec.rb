require 'rails_helper'

RSpec.describe WeeklyStrategyAnalysisJob, type: :job do
  describe '#perform' do
    before do
      # Prevent Rails.logger from raising in test environment
      allow(Rails.logger).to receive(:error) do |message|
        # Do nothing - just prevent the exception
      end
      allow(Rails.logger).to receive(:info) do |message|
        # Do nothing
      end
      allow(Rails.logger).to receive(:warn) do |message|
        # Do nothing
      end
    end
    
    it 'does not raise when executed' do
      job = WeeklyStrategyAnalysisJob.new
      expect { job.perform }.not_to raise_error
    end
    
    it 'does not raise when executed for specific user' do
      job = WeeklyStrategyAnalysisJob.new
      expect { job.perform(99999) }.not_to raise_error
    end
  end
end
