# Service for agency dashboard metrics and client management
module Analytics
  class AgencyDashboardService
    def initialize(agency_user)
      @agency_user = agency_user
    end

    # Get all clients managed by the agency
    def clients
      Client.where(agency_user: @agency_user).or(
        Client.where(user: @agency_user)
      ).order(created_at: :desc)
    end

    # Get campaigns overview for agency
    def campaigns_overview
      client_ids = clients.pluck(:id)
      
      {
        total: Campaign.where(client_id: client_ids).count,
        running: Campaign.where(client_id: client_ids).where(status: :running).count,
        paused: Campaign.where(client_id: client_ids).where(status: :paused).count,
        completed: Campaign.where(client_id: client_ids).where(status: :completed).count,
        failed: Campaign.where(client_id: client_ids).where(status: :failed).count,
        draft: Campaign.where(client_id: client_ids).where(status: :draft).count
      }
    end

    # Get task statistics
    def tasks_overview
      client_ids = clients.pluck(:id)
      campaign_ids = Campaign.where(client_id: client_ids).pluck(:id)
      
      {
        pending: CampaignTask.where(campaign_id: campaign_ids).where(status: :pending).count,
        completed: CampaignTask.where(campaign_id: campaign_ids).where(status: :completed).count,
        failed: CampaignTask.where(campaign_id: campaign_ids).where(status: :failed).count
      }
    end

    # Get cost tracking per client
    def cost_tracking
      client_ids = clients.pluck(:id)
      
      clients.map do |client|
        usage = CampaignUsage.where(campaign_id: client.campaign_ids).sum(:estimated_cost)
        {
          client_id: client.id,
          client_name: client.name,
          total_cost: usage,
          budget: client.monthly_budget,
          percent_used: client.monthly_budget ? (usage / client.monthly_budget * 100).round(2) : 0
        }
      end
    end

    # Get alerts for failed campaigns or API errors
    def alerts
      client_ids = clients.pluck(:id)
      campaign_ids = Campaign.where(client_id: client_ids).pluck(:id)
      
      alerts = []

      # Failed campaigns
      Campaign.where(id: campaign_ids, status: :failed).find_each do |campaign|
        alerts << {
          type: 'campaign_failed',
          severity: 'high',
          message: "Campaign '#{campaign.name}' has failed",
          campaign_id: campaign.id,
          client_id: campaign.client_id,
          created_at: campaign.updated_at
        }
      end

      # Recent failed tasks
      CampaignTask.where(campaign_id: campaign_ids)
        .where(status: :failed)
        .where('created_at > ?', 24.hours.ago)
        .find_each do |task|
        alerts << {
          type: 'task_failed',
          severity: 'medium',
          message: "Task '#{task.tool_name}' failed: #{task.error_message&.truncate(50)}",
          campaign_id: task.campaign_id,
          campaign_task_id: task.id,
          created_at: task.updated_at
        }
      end

      # Campaigns needing approval (safe_mode)
      Campaign.where(id: campaign_ids)
        .where(safe_mode: true)
        .where.not(optimization_approval_status: 'approved')
        .find_each do |campaign|
        alerts << {
          type: 'approval_needed',
          severity: 'low',
          message: "Campaign '#{campaign.name}' needs optimization approval",
          campaign_id: campaign.id,
          client_id: campaign.client_id,
          created_at: campaign.updated_at
        }
      end

      alerts.sort_by { |a| [a[:severity] == 'high' ? 0 : 1, a[:created_at]] }.reverse
    end

    # Get engagement trends
    def engagement_trends(days: 7)
      client_ids = clients.pluck(:id)
      
      # Get published posts with metrics in the date range
      posts = ScheduledPost.published
        .where('scheduled_posts.published_at > ?', days.days.ago)
        .joins(:performance_metric)
        .joins(:campaign)
        .where(campaigns: { client_id: client_ids })
        .includes(:performance_metric, :campaign)

      # Group by day
      trends = {}
      days.times do |i|
        date = (i + 1).days.ago.to_date
        trends[date] = { likes: 0, comments: 0, shares: 0, views: 0, posts: 0 }
      end

      posts.each do |post|
        date = post.published_at.to_date
        next unless trends[date]
        
        pm = post.performance_metric
        trends[date][:likes] += pm.likes || 0
        trends[date][:comments] += pm.comments || 0
        trends[date][:shares] += pm.shares || 0
        trends[date][:views] += pm.views || 0
        trends[date][:posts] += 1
      end

      trends
    end

    # Get data for a specific client
    def client_overview(client_id)
      client = clients.find_by(id: client_id)
      return nil unless client

      {
        client: client,
        campaigns: {
          total: client.campaigns.count,
          running: client.campaigns.where(status: :running).count,
          active: client.campaigns.where(status: :running).count
        },
        tasks: {
          pending: CampaignTask.where(campaign: client.campaigns).where(status: :pending).count,
          completed: CampaignTask.where(campaign: client.campaigns).where(status: :completed).count,
          failed: CampaignTask.where(campaign: client.campaigns).where(status: :failed).count
        },
        total_cost: CampaignUsage.where(campaign: client.campaigns).sum(:estimated_cost),
        social_accounts_count: client.social_accounts.count,
        posts_this_month: client.scheduled_posts.where('published_at > ?', 30.days.ago).count
      }
    end
  end
end
