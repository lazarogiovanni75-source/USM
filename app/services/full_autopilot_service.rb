# frozen_string_literal: true

# Full Autopilot Service - Autonomous Social Media Manager
# Coordinates Research → Create → Optimize → Schedule → Post → Analyze
# Now uses campaign data for context-aware content generation

class FullAutopilotService
  class AutopilotError < StandardError; end

  attr_reader :user, :campaign, :run_id, :status, :results, :errors, :context

  def initialize(user:, campaign: nil, run_id: nil)
    @user = user
    @campaign = campaign
    @run_id = run_id || SecureRandom.hex(8)
    @status = :initialized
    @results = { research_count: 0, content_created: 0, images_generated: 0, posts_scheduled: 0, posts_published: 0, tools_used: [] }
    @errors = []
    @current_phase = :research
    @context = build_context
  end

  def start
    Rails.logger.info "[FullAutopilot] Starting for user #{@user.id}#{@campaign ? " (Campaign: #{@campaign.name})" : ""}"
    @status = :running
    
    begin
      research_phase if should_research?
      creation_phase if should_create_content?
      scheduling_phase if should_schedule?
      @status = :completed
    rescue => e
      @status = :failed
      @errors << { phase: @current_phase, error: e.message }
      Rails.logger.error "[FullAutopilot] Error in phase #{@current_phase}: #{e.message}"
    end
    
    finalize_results
  end

  private

  # Build rich context from campaign data
  def build_context
    context = {
      user_name: @user.name,
      user_email: @user.email,
      has_campaign: @campaign.present?
    }

    if @campaign
      context.merge!({
        campaign_name: @campaign.name,
        campaign_description: @campaign.description,
        campaign_goal: @campaign.goal,
        target_audience: @campaign.target_audience,
        platforms: @campaign.platforms || [],
        content_pillars: @campaign.content_pillars || [],
        hashtag_set: @campaign.hashtag_set || [],
        campaign_type: @campaign.campaign_type,
        budget: @campaign.budget,
        start_date: @campaign.start_date,
        end_date: @campaign.end_date
      })
    end

    context
  end

  def should_research?; true; end
  def should_create_content?; true; end
  def should_schedule?; true; end

  def research_phase
    @current_phase = :research
    Rails.logger.info "[FullAutopilot] Research phase with context: #{@context[:campaign_name] || 'No campaign'}"

    # Build research prompt with campaign context
    research_prompt = build_research_prompt
    
    response = LlmService.generate(research_prompt, user: @user)
    if response.present?
      @results[:research_count] += 1
      @results[:research_data] = response
      Rails.logger.info "[FullAutopilot] Research completed"
    else
      @errors << { phase: :research, error: "No research results returned" }
    end
  rescue => e
    @errors << { phase: :research, error: e.message }
    Rails.logger.error "[FullAutopilot] Research error: #{e.message}"
  end

  def build_research_prompt
    base = "Find trending topics and relevant hashtags for "
    
    if @campaign
      base += <<~PROMPT
        the "#{@campaign.name}" campaign.
        
        Campaign Details:
        - Description: #{@campaign.description || 'Not specified'}
        - Goal: #{@campaign.goal || 'Not specified'}
        - Target Audience: #{@campaign.target_audience || 'General audience'}
        - Platforms: #{@campaign.platforms&.join(', ') || 'All platforms'}
        - Content Pillars: #{@campaign.content_pillars&.join(', ') || 'General content'}
        - Existing Hashtags: #{@campaign.hashtag_set&.join(', ') || 'None'}
      PROMPT
    else
      base += "#{@user.name}'s social media presence"
    end
    
    base += "\n\nProvide 3-5 trending topics with relevant hashtags and brief descriptions of why they're relevant."
    base
  end

  def creation_phase
    @current_phase = :creation
    Rails.logger.info "[FullAutopilot] Creation phase"

    # Build content creation prompt with full context
    content_prompt = build_content_prompt
    
    content = LlmService.generate(content_prompt, user: @user)
    if content.present?
      # Determine primary platform
      primary_platform = @context[:platforms]&.first || 'general'
      
      # Create draft content with campaign association
      draft = DraftContent.create!(
        user: @user,
        title: @campaign ? "Autopilot: #{@campaign.name} - #{Time.current.strftime('%Y-%m-%d')}" : "Autopilot Content - #{Time.current.strftime('%Y-%m-%d')}",
        content: content,
        content_type: 'post',
        platform: primary_platform,
        status: 'draft',
        metadata: {
          run_id: @run_id,
          all_platforms: @context[:platforms],
          hashtags: @context[:hashtag_set],
          research_data: @results[:research_data]
        }.compact
      )
      @results[:content_created] += 1
      @results[:draft_id] = draft.id
      Rails.logger.info "[FullAutopilot] Created draft content ##{draft.id}"
    else
      @errors << { phase: :creation, error: "No content generated" }
    end
  rescue => e
    @errors << { phase: :creation, error: e.message }
    Rails.logger.error "[FullAutopilot] Creation error: #{e.message}"
  end

  def build_content_prompt
    prompt = "Create 3 engaging social media posts optimized for engagement. "
    
    if @campaign
      prompt += <<~PROMPT
        
        Campaign: "#{@campaign.name}"
        Goal: #{@campaign.goal || 'engagement'}
        Target Audience: #{@campaign.target_audience || 'General audience'}
        Content Pillars: #{@campaign.content_pillars&.join(', ') || 'General content'}
        
        Format each post with:
        1. A compelling hook (first line)
        2. Main body (2-3 sentences)
        3. Call to action
        4. Relevant hashtags (3-5 from: #{@campaign.hashtag_set&.join(', ') || 'general hashtags'})
        
        Make each post suitable for: #{@campaign.platforms&.join(', ') || 'all social platforms'}
        
        Previous research: #{@results[:research_data] || 'Use general trending topics'}
      PROMPT
    else
      prompt += "\n\nCreate varied content covering different angles and formats."
    end
    
    prompt += "\n\nReturn posts separated by '---POST---'"
    prompt
  end

  def scheduling_phase
    @current_phase = :scheduling
    Rails.logger.info "[FullAutopilot] Scheduling phase"

    # Get drafts created by this run
    drafts = @user.draft_contents.where("created_at > ?", 1.hour.ago).order(created_at: :desc)
    
    unless drafts.any?
      Rails.logger.info "[FullAutopilot] No drafts to schedule"
      return
    end

    # Get available social accounts from Postforme
    postforme = PostformeService.new
    social_accounts_data = postforme.social_accounts
    
    account_ids = if social_accounts_data['data'].present?
      social_accounts_data['data'].map { |a| a['id'] }
    else
      # Fall back to user's connected social accounts
      @user.social_accounts.pluck(:id)
    end

    unless account_ids.any?
      @errors << { phase: :scheduling, error: "No social accounts connected" }
      Rails.logger.warn "[FullAutopilot] No social accounts available"
      return
    end

    # Schedule each draft
    drafts.first(3).each_with_index do |draft, index|
      schedule_via_postforme(draft, account_ids, index)
    end
    
    Rails.logger.info "[FullAutopilot] Scheduling completed: #{@results[:posts_scheduled]} posts scheduled"
  rescue => e
    @errors << { phase: :scheduling, error: e.message }
    Rails.logger.error "[FullAutopilot] Scheduling error: #{e.message}"
  end

  def schedule_via_postforme(draft, account_ids, index = 0)
    return unless draft.content.present?
    
    postforme = PostformeService.new
    
    # Schedule 1-4 hours from now, staggered
    scheduled_time = (index + 1).hours.from_now
    
    result = postforme.create_post(
      account_ids,
      draft.content,
      scheduled_at: scheduled_time,
      campaign_id: @campaign&.id
    )
    
    if result['data']
      @results[:posts_scheduled] += 1
      
      # Create scheduled post record if we have the postforme post ID
      post_id = result.dig('data', 'id')
      if post_id
        ScheduledPost.create!(
          user: @user,
          campaign: @campaign,
          draft_content: draft,
          postforme_id: post_id.to_s,
          scheduled_at: scheduled_time,
          status: 'scheduled'
        )
      end
    end
  rescue => e
    @errors << { phase: :scheduling, error: "Postforme: #{e.message}" }
  end

  def finalize_results
    @results.merge(
      status: @status,
      run_id: @run_id,
      errors: @errors,
      context_summary: {
        campaign: @context[:campaign_name],
        platforms: @context[:platforms],
        content_created: @results[:content_created],
        posts_scheduled: @results[:posts_scheduled]
      }
    )
  end
end
