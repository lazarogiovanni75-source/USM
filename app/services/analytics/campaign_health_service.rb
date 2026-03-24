# frozen_string_literal: true

module Analytics
  # Service for calculating campaign health metrics
  # Provides observability data for admin dashboard
  class CampaignHealthService
    class << self
      # Get comprehensive health data for a campaign
      # @param campaign [Campaign]
      # @return [Hash] Health metrics
      def call(campaign)
        return empty_health if campaign.blank?

        tasks = campaign.tasks
        posts = campaign.scheduled_posts
        metrics = CampaignMetricsAggregator.call(campaign)
        usage = Ai::UsageTracker.current_usage(campaign)

        {
          campaign_id: campaign.id,
          status: campaign.status,
          success_rate: calculate_success_rate(tasks),
          failure_rate: calculate_failure_rate(tasks),
          publish_latency: calculate_publish_latency(posts),
          engagement_trend: calculate_engagement_trend(metrics),
          cost_so_far: usage[:estimated_cost],
          roi_proxy: calculate_roi_proxy(metrics, usage[:estimated_cost]),
          total_posts: posts.count,
          published_posts: posts.published.count,
          total_tasks: tasks.count,
          completed_tasks: tasks.done.count,
          failed_tasks: tasks.failed.count,
          pending_tasks: tasks.pending.count,
          impressions: metrics[:total_impressions] || 0,
          avg_engagement_rate: metrics[:avg_engagement_rate] || 0.0,
          calculated_at: Time.current.iso8601
        }
      end

      # Get health for multiple campaigns
      # @param campaigns [ActiveRecord::Relation]
      # @return [Array<Hash>]
      def batch_call(campaigns)
        campaigns.map { |campaign| call(campaign) }
      end

      # Get overall platform health
      # @return [Hash]
      def overall_health
        campaigns = Campaign.all

        {
          total_campaigns: campaigns.count,
          active_campaigns: campaigns.running.count,
          paused_campaigns: campaigns.paused.count,
          completed_campaigns: campaigns.completed.count,
          failed_campaigns: campaigns.failed.count,
          total_cost: Ai::UsageTracker.all.sum(&:estimated_cost).to_f,
          total_posts_published: ScheduledPost.published.count,
          avg_success_rate: calculate_avg_success_rate(campaigns),
          calculated_at: Time.current.iso8601
        }
      end

      private

      def calculate_success_rate(tasks)
        total = tasks.count
        return 0.0 if total.zero?

        ((tasks.done.count.to_f / total) * 100).round(2)
      end

      def calculate_failure_rate(tasks)
        total = tasks.count
        return 0.0 if total.zero?

        ((tasks.failed.count.to_f / total) * 100).round(2)
      end

      def calculate_publish_latency(posts)
        published = posts.published.where.not(published_at: nil)
        return nil if published.count < 2

        # Average time between scheduled and published
        latencies = published.map do |post|
          next nil unless post.scheduled_at && post.published_at

          (post.published_at - post.scheduled_at).to_i.abs
        end.compact

        return nil if latencies.empty?

        (latencies.sum.to_f / latencies.size / 60).round(2) # in minutes
      end

      def calculate_engagement_trend(metrics)
        # Simple trend based on top vs worst posts
        top = metrics[:top_posts]&.first&.dig(:engagement_rate) || 0
        worst = metrics[:worst_posts]&.first&.dig(:engagement_rate) || 0

        if top.zero? && worst.zero?
          'neutral'
        elsif top > worst * 2
          'improving'
        elsif worst > top * 2
          'declining'
        else
          'stable'
        end
      end

      def calculate_roi_proxy(metrics, cost)
        return 0.0 if cost.zero?

        engagement = metrics[:total_impressions].to_i +
                   (metrics[:avg_engagement_rate].to_f * 100 * metrics[:total_posts].to_i)

        (engagement / cost).round(2)
      end

      def calculate_avg_success_rate(campaigns)
        return 0.0 if campaigns.empty?

        total_tasks = campaigns.joins(:tasks).count
        return 0.0 if total_tasks.zero?

        completed = campaigns.joins(:tasks).where(campaign_tasks: { status: :done }).count
        ((completed.to_f / total_tasks) * 100).round(2)
      end

      def empty_health
        {
          campaign_id: nil,
          status: nil,
          success_rate: 0.0,
          failure_rate: 0.0,
          publish_latency: nil,
          engagement_trend: 'neutral',
          cost_so_far: 0.0,
          roi_proxy: 0.0,
          total_posts: 0,
          published_posts: 0,
          total_tasks: 0,
          completed_tasks: 0,
          failed_tasks: 0,
          pending_tasks: 0,
          impressions: 0,
          avg_engagement_rate: 0.0,
          calculated_at: Time.current.iso8601
        }
      end
    end
  end
end
