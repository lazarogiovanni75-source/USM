# frozen_string_literal: true

module Ai
  module Tools
    class AdjustStrategy
      class Error < StandardError; end

      def self.call(user:, campaign:, changes: {}, **)
        Rails.logger.info "[Tools::AdjustStrategy] Adjusting campaign #{campaign.id} strategy"

        return { success: false, error: 'Campaign required' } unless campaign

        current_strategy = campaign.strategy || {}
        new_strategy = current_strategy.merge(changes)

        campaign.update!(strategy: new_strategy)

        {
          success: true,
          campaign_id: campaign.id,
          previous_strategy: current_strategy,
          new_strategy: new_strategy,
          changes: changes
        }
      end
    end
  end
end
