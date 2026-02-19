# frozen_string_literal: true

module Ai
  module Tools
    class IncreaseFrequency
      class Error < StandardError; end

      def self.call(user:, campaign:, posts_per_day: nil, **)
        Rails.logger.info "[Tools::IncreaseFrequency] Increasing frequency for campaign #{campaign.id}"

        return { success: false, error: 'Campaign required' } unless campaign

        current_strategy = campaign.strategy || {}
        current_frequency = current_strategy['posts_per_day'] || 1
        
        new_frequency = posts_per_day || (current_frequency + 1)
        new_strategy = current_strategy.merge('posts_per_day' => new_frequency)

        campaign.update!(strategy: new_strategy)

        {
          success: true,
          campaign_id: campaign.id,
          previous_frequency: current_frequency,
          new_frequency: new_frequency
        }
      end
    end
  end
end
