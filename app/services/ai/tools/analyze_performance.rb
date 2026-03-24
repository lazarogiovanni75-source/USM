# frozen_string_literal: true

module Ai
  module Tools
    class AnalyzePerformance
      class Error < StandardError; end

      def self.call(user:, campaign: nil, campaign_id: nil, days: 7, **)
        Rails.logger.info "[Tools::AnalyzePerformance] Analyzing performance"

        target_campaign = find_campaign(campaign, campaign_id)
        return { success: false, error: 'Campaign not found' } unless target_campaign

        # Aggregate metrics
        metrics = Analytics::CampaignMetricsAggregator.call(target_campaign)

        # Fetch fresh metrics from platforms
        fresh_metrics = fetch_platform_metrics(target_campaign)

        {
          success: true,
          campaign_id: target_campaign.id,
          aggregated: metrics,
          platform_metrics: fresh_metrics,
          period_days: days,
          analyzed_at: Time.current.iso8601
        }
      rescue => e
        Rails.logger.error "[Tools::AnalyzePerformance] Error: #{e.message}"
        { success: false, error: e.message }
      end

      # Pull metrics from platforms and store in PostMetric
      def self.pull_metrics(user:, post_id: nil, post_ids: [], **)
        Rails.logger.info "[Tools::AnalyzePerformance] Pulling metrics"

        posts = if post_id.present?
                  [ScheduledPost.find_by(id: post_id)]
                elsif post_ids.present?
                  ScheduledPost.where(id: post_ids).to_a
                else
                  ScheduledPost.where(user_id: user.id)
                              .where(status: 'published')
                              .where('published_at >= ?', 7.days.ago)
                              .to_a
                end

        results = posts.map do |post|
          pull_and_store_metrics(post)
        end

        {
          success: true,
          processed: results.count,
          results: results
        }
      end

      private

      def self.find_campaign(campaign, campaign_id)
        campaign || (campaign_id.present? && Campaign.find_by(id: campaign_id))
      end

      def self.fetch_platform_metrics(campaign)
        return {} unless campaign.user

        social_accounts = SocialAccount.where(user_id: campaign.user.id)
        metrics = {}

        social_accounts.each do |account|
          next unless account.configured_for_postforme?

          begin
            publisher = Social::Publisher.for_platform(account.platform, account)
            account_metrics = publisher.fetch_account_metrics
            metrics[account.platform] = account_metrics
          rescue => e
            Rails.logger.warn "[AnalyzePerformance] Failed to fetch #{account.platform}: #{e.message}"
          end
        end

        metrics
      end

      def self.pull_and_store_metrics(post)
        return { post_id: post.id, success: false, error: 'No postforme_post_id' } unless post.postforme_post_id

        begin
          client = Social::PostformeClient.new
          metrics = client.fetch_metrics(post.postforme_post_id)

          if metrics[:success]
            PostMetric.find_or_initialize_by(
              post_type: 'ScheduledPost',
              post_id: post.id,
              platform: post.platform,
              collected_at: Time.current
            ).update!(
              social_account_id: post.social_account_id,
              platform_post_id: post.postforme_post_id,
              impressions: metrics[:impressions] || 0,
              likes: metrics[:likes] || 0,
              comments: metrics[:comments] || 0,
              shares: metrics[:shares] || 0,
              saves: metrics[:saves] || 0,
              clicks: metrics[:clicks] || 0,
              engagement_rate: metrics[:engagement_rate] || 0.0,
              raw_metrics: metrics[:raw_metrics]
            )

            { post_id: post.id, success: true, metrics: metrics }
          else
            { post_id: post.id, success: false, error: metrics[:error] }
          end
        rescue => e
          { post_id: post.id, success: false, error: e.message }
        end
      end
    end
  end
end
