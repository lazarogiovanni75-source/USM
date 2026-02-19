# frozen_string_literal: true

module Ai
  module Tools
    class TestNewFormat
      class Error < StandardError; end

      def self.call(user:, campaign:, format: nil, description: nil, **)
        Rails.logger.info "[Tools::TestNewFormat] Testing new format for campaign #{campaign.id}"

        return { success: false, error: 'Campaign required' } unless campaign
        return { success: false, error: 'Format required' } unless format

        current_strategy = campaign.strategy || {}
        test_formats = current_strategy['testing_formats'] || []
        
        new_test = {
          format: format,
          description: description,
          started_at: Time.current.iso8601,
          status: 'active'
        }
        
        test_formats << new_test
        new_strategy = current_strategy.merge('testing_formats' => test_formats)

        campaign.update!(strategy: new_strategy)

        {
          success: true,
          campaign_id: campaign.id,
          new_format: format,
          description: description,
          tests_count: test_formats.count
        }
      end
    end
  end
end
