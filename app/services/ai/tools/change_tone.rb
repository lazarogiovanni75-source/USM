# frozen_string_literal: true

module Ai
  module Tools
    class ChangeTone
      class Error < StandardError; end

      def self.call(user:, campaign:, tone: nil, **)
        Rails.logger.info "[Tools::ChangeTone] Changing tone for campaign #{campaign.id}"

        return { success: false, error: 'Campaign required' } unless campaign
        return { success: false, error: 'Tone required' } unless tone

        current_strategy = campaign.strategy || {}
        new_strategy = current_strategy.merge('tone' => tone, 'tone_changed_at' => Time.current.iso8601)

        campaign.update!(strategy: new_strategy)

        {
          success: true,
          campaign_id: campaign.id,
          previous_tone: current_strategy['tone'],
          new_tone: tone
        }
      end
    end
  end
end
