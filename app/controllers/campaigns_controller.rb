class CampaignsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :add_content, :remove_content, :duplicate, :analytics, :schedule_all, :publish_now]

  def index
    @campaigns = current_user.campaigns.includes(:contents, :social_accounts)
                              .order(created_at: :desc)
    @campaigns = @campaigns.by_status(params[:status]) if params[:status].present?
    @campaigns = @campaigns.search(params[:search]) if params[:search].present?
    
    @stats = {
      total: @campaigns.count,
      active: @campaigns.active.count,
      draft: @campaigns.draft.count,
      completed: @campaigns.completed.count
    }
    
    @recent_campaigns = @campaigns.recent.limit(5)
  end

  def show
    @contents = @campaign.contents.order(created_at: :desc)
    @social_accounts = @campaign.social_accounts
    @analytics = CampaignAnalyticsService.new(@campaign)
    @performance = @analytics.get_performance_summary(30)
    @scheduled_posts = @campaign.scheduled_posts.upcoming.includes(:content, :social_account)
  end

  def new
    @campaign = Campaign.new
    @social_accounts = current_user.social_accounts
    @templates = current_user.content_templates.limit(5)
  end

  def create
    @campaign = current_user.campaigns.build(campaign_params)
    
    if @campaign.save
      if params[:social_account_ids].present?
        @campaign.social_account_ids = params[:social_account_ids]
      end
      
      # Handle AI Workflow if prompt provided
      if params[:ai_prompt].present?
        begin
          result = WorkflowService.new(current_user).create_content_with_media(
            content_text: params[:ai_prompt],
            generate_image: params[:generate_image].to_i == 1,
            generate_video: params[:generate_video].to_i == 1,
            post_now: params[:post_now].to_i == 1,
            scheduled_at: params[:scheduled_at].present? ? params[:scheduled_at] : nil,
            social_account_ids: params[:social_account_ids] || [],
            campaign_id: @campaign.id
          )
          
          if result[:success]
            flash[:notice] = "Campaign created! #{result[:message]}"
          else
            flash[:warning] = "Campaign created but AI workflow failed: #{result[:error]}"
          end
        rescue => e
          Rails.logger.error("AI Workflow Error: #{e.message}")
          flash[:warning] = "Campaign created but AI workflow encountered an error."
        end
      elsif params[:template_id].present?
        generate_content_from_template(params[:template_id])
      end
      
      redirect_to campaign_path(@campaign), notice: 'Campaign was successfully created.'
    else
      @social_accounts = current_user.social_accounts
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @social_accounts = current_user.social_accounts
    @available_contents = current_user.contents.where(campaign_id: nil).recent.limit(20)
  end

  def update
    if @campaign.update(campaign_params)
      if params[:social_account_ids].present?
        @campaign.social_account_ids = params[:social_account_ids]
      end
      
      redirect_to campaign_path(@campaign), notice: 'Campaign was successfully updated.'
    else
      @social_accounts = current_user.social_accounts
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_url, notice: 'Campaign was successfully deleted.'
  end

  def add_content
    content = current_user.contents.find(params[:content_id])
    @campaign.contents << content
    redirect_to campaign_path(@campaign), notice: 'Content added to campaign.'
  end

  def remove_content
    content = @campaign.contents.find(params[:content_id])
    @campaign.contents.destroy(content)
    redirect_to campaign_path(@campaign), notice: 'Content removed from campaign.'
  end

  def duplicate
    new_campaign = @campaign.duplicate
    redirect_to campaign_path(new_campaign), notice: 'Campaign duplicated successfully.'
  end

  def analytics
    @analytics = CampaignAnalyticsService.new(@campaign)
    @performance = @analytics.get_performance_summary(params[:days].to_i || 30)
    @trends = @analytics.get_trends
    @recommendations = @analytics.get_recommendations
  end

  def schedule_all
    scheduled_count = 0
    failed_count = 0
    
    @campaign.contents.draft.each do |content|
      @campaign.social_accounts.each do |account|
        post = content.schedule_for(account, Time.current + 1.hour)
        if post.persisted?
          scheduled_count += 1
        else
          failed_count += 1
        end
      end
    end
    
    redirect_to campaign_path(@campaign), notice: "Scheduled #{scheduled_count} posts. #{failed_count} failed."
  end

  def publish_now
    published_count = 0
    failed_count = 0
    
    @campaign.contents.draft.each do |content|
      result = content.publish_now
      if result[:success]
        published_count += 1
      else
        failed_count += 1
      end
    end
    
    redirect_to campaign_path(@campaign), notice: "Published #{published_count} posts. #{failed_count} failed."
  end

  def bulk_actions
    campaign_ids = params[:campaign_ids] || []
    action = params[:bulk_action]
    
    case action
    when 'activate'
      current_user.campaigns.where(id: campaign_ids).update_all(status: 'active')
      message = "#{campaign_ids.count} campaigns activated"
    when 'pause'
      current_user.campaigns.where(id: campaign_ids).update_all(status: 'paused')
      message = "#{campaign_ids.count} campaigns paused"
    when 'complete'
      current_user.campaigns.where(id: campaign_ids).update_all(status: 'completed')
      message = "#{campaign_ids.count} campaigns completed"
    when 'delete'
      current_user.campaigns.where(id: campaign_ids).destroy_all
      message = "#{campaign_ids.count} campaigns deleted"
    end
    
    redirect_to campaigns_url, notice: message
  end

  def export
    @campaigns = current_user.campaigns.includes(:contents, :social_accounts)
    
    csv_data = generate_campaigns_csv(@campaigns)
    send_data csv_data, filename: "campaigns_#{Date.current}.csv"
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(
      :name, :description, :target_audience, :budget, :start_date, :end_date,
      :status, :goal, :goal_value, :platforms, :content_count,
      :hashtag_set, :mentions, :campaign_type, :content_pillars,
      :key_messages, :brand_guidelines, :competitors, :influencer_targets,
      :budget_allocation, :kpis, :success_metrics
    )
  end

  def generate_content_from_template(template_id)
    template = current_user.content_templates.find_by(id: template_id)
    return unless template
    
    3.times do |i|
      content = template.generate_content(
        user: current_user,
        campaign: @campaign,
        index: i + 1
      )
    end
  end

  def generate_campaigns_csv(campaigns)
    CSV.generate do |csv|
      csv << ['Name', 'Status', 'Start Date', 'End Date', 'Budget', 'Content Count', 'Platforms', 'Created At']
      
      campaigns.each do |campaign|
        csv << [
          campaign.name,
          campaign.status,
          campaign.start_date,
          campaign.end_date,
          campaign.budget,
          campaign.contents.count,
          campaign.platforms,
          campaign.created_at.strftime('%Y-%m-%d %H:%M')
        ]
      end
    end
  end
end
