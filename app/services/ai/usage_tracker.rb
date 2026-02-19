# frozen_string_literal: true

module Ai
  # Tracks usage and costs per campaign
  # Monitors LLM tokens, image generations, Postforme API calls, and estimated costs
  class UsageTracker
    # Cost constants (in USD)
    LLM_TOKEN_COST_PER_1K = 0.002  # $2 per 1M tokens
    IMAGE_GENERATION_COST = 0.04   # $0.04 per image
    POSTFORME_API_CALL_COST = 0.001 # $0.001 per API call

    class << self
      # Record LLM token usage
      # @param campaign [Campaign]
      # @param tokens [Integer] Number of tokens used
      def track_llm_tokens(campaign, tokens)
        return unless campaign.present? && tokens.to_i.positive?

        usage = find_or_initialize_usage(campaign)
        usage.llm_tokens += tokens.to_i
        usage.estimated_cost += calculate_llm_cost(tokens)
        usage.save!
      end

      # Record image generation
      # @param campaign [Campaign]
      # @param count [Integer] Number of images generated
      def track_images_generated(campaign, count = 1)
        return unless campaign.present? && count.to_i.positive?

        usage = find_or_initialize_usage(campaign)
        usage.images_generated += count.to_i
        usage.estimated_cost += calculate_image_cost(count)
        usage.save!
      end

      # Record post published
      # @param campaign [Campaign]
      # @param count [Integer] Number of posts published
      def track_post_published(campaign, count = 1)
        return unless campaign.present? && count.to_i.positive?

        usage = find_or_initialize_usage(campaign)
        usage.posts_published += count.to_i
        usage.save!
      end

      # Record Postforme API call
      # @param campaign [Campaign]
      # @param count [Integer] Number of API calls
      def track_api_call(campaign, count = 1)
        return unless campaign.present? && count.to_i.positive?

        usage = find_or_initialize_usage(campaign)
        usage.api_calls += count.to_i
        usage.estimated_cost += calculate_api_call_cost(count)
        usage.save!
      end

      # Get current usage for a campaign
      # @param campaign [Campaign]
      # @return [Hash] Usage statistics
      def current_usage(campaign)
        return empty_usage unless campaign.present?

        usage = CampaignUsage.find_by(campaign_id: campaign.id)
        return empty_usage unless usage

        {
          llm_tokens: usage.llm_tokens,
          images_generated: usage.images_generated,
          posts_published: usage.posts_published,
          api_calls: usage.api_calls,
          estimated_cost: usage.estimated_cost.to_f,
          updated_at: usage.updated_at
        }
      end

      # Check if campaign has exceeded any hard limits
      # @param campaign [Campaign]
      # @param limits [Hash] Custom limits (optional)
      # @return [Hash] { exceeded: boolean, reasons: [] }
      def check_limits(campaign, limits = {})
        limits = default_limits.merge(limits)
        usage = current_usage(campaign)
        reasons = []

        if usage[:estimated_cost] >= limits[:max_cost]
          reasons << "cost_limit: $#{limits[:max_cost]} exceeded"
        end

        if usage[:images_generated] >= limits[:max_images]
          reasons << "images_limit: #{limits[:max_images]} exceeded"
        end

        if usage[:posts_published] >= limits[:max_posts]
          reasons << "posts_limit: #{limits[:max_posts]} exceeded"
        end

        {
          exceeded: reasons.any?,
          reasons: reasons,
          current: usage,
          limits: limits
        }
      end

      # Get default hard limits
      def default_limits
        {
          max_cost: ENV.fetch('CAMPAIGN_MAX_COST', 20).to_f,
          max_images: ENV.fetch('CAMPAIGN_MAX_IMAGES', 50).to_i,
          max_posts: ENV.fetch('CAMPAIGN_MAX_POSTS', 100).to_i,
          max_optimization_cycles: ENV.fetch('CAMPAIGN_MAX_OPTIMIZATION_CYCLES', 10).to_i
        }
      end

      private

      def find_or_initialize_usage(campaign)
        CampaignUsage.find_or_initialize_by(campaign_id: campaign.id)
      end

      def calculate_llm_cost(tokens)
        (tokens.to_i * LLM_TOKEN_COST_PER_1K / 1000).round(4)
      end

      def calculate_image_cost(count)
        (count.to_i * IMAGE_GENERATION_COST).round(4)
      end

      def calculate_api_call_cost(count)
        (count.to_i * POSTFORME_API_CALL_COST).round(4)
      end

      def empty_usage
        {
          llm_tokens: 0,
          images_generated: 0,
          posts_published: 0,
          api_calls: 0,
          estimated_cost: 0.0,
          updated_at: nil
        }
      end
    end
  end
end
