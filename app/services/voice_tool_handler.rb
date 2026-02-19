# frozen_string_literal: true

# Voice Tool Handler - Executes AI tools for voice commands
# Validates arguments, checks permissions, executes services
class VoiceToolHandler
  class ExecutionError < StandardError; end

  def initialize(user:, execution_id: nil)
    @user = user
    @execution_id = execution_id || SecureRandom.uuid
  end

  # Main entry point - handles tool execution
  # Returns structured result for LLM context
  def execute(tool_name, arguments)
    Rails.logger.info "[VoiceToolHandler] Executing: #{tool_name} with args: #{arguments.inspect} - execution_id: #{@execution_id}"

    result = case tool_name
              when "generate_content" then generate_content(arguments)
              when "generate_image" then generate_image(arguments)
              when "generate_video" then generate_video(arguments)
              when "schedule_post" then schedule_post(arguments)
              when "create_campaign" then create_campaign(arguments)
              when "analyze_performance" then analyze_performance(arguments)
              else
                { error: "Unknown tool: #{tool_name}" }
              end

    format_result(tool_name, result)
  rescue => e
    Rails.logger.error "[VoiceToolHandler] Error: #{e.message}"
    format_error(tool_name, e.message)
  end

  # Check if tool requires user confirmation
  def requires_confirmation?(tool_name)
    AiVoiceTools.requires_confirmation?(tool_name)
  end

  private

  def generate_content(args)
    topic = args["topic"] || "general content"
    platform = args["platform"] || "general"
    tone = args["tone"] || "professional"
    content_type = args["content_type"] || "post"

    content = AiAutopilotService.new(
      action: 'generate_content',
      campaign: @user.campaigns.last,
      content_type: content_type,
      platform: platform
    ).call

    {
      status: "success",
      content: content,
      topic: topic,
      platform: platform,
      tone: tone,
      message: "Content generated successfully!"
    }
  rescue => e
    { status: "error", error: e.message }
  end

  def generate_image(args)
    prompt = args["prompt"]
    style = args["style"] || "photorealistic"
    size = args["size"] || "square"

    image_service = OpenAiImageService.new
    result = image_service.generate_image(
      prompt: prompt,
      style: style,
      size: size
    )

    {
      status: "success",
      image_url: result[:url],
      prompt: prompt,
      style: style,
      message: "Image generated! You can view it at: #{result[:url]}"
    }
  rescue => e
    Rails.logger.error "Image generation error: #{e.message}"
    { status: "error", error: e.message }
  end

  def generate_video(args)
    topic = args["topic"]
    duration = args["duration"] || 10
    style = args["style"] || "social"

    # Create video job
    video = Video.create!(
      user: @user,
      topic: topic,
      duration: duration,
      style: style,
      status: "processing"
    )

    # Queue video generation job
    GenerateVideoJob.perform_later(video.id)

    {
      status: "processing",
      video_id: video.id,
      topic: topic,
      duration: duration,
      message: "Video generation started! I'll notify you when it's ready."
    }
  rescue => e
    { status: "error", error: e.message }
  end

  def schedule_post(args)
    content = args["content"]
    platform = args["platform"]
    scheduled_time = args["scheduled_time"]
    media_urls = args["media_urls"] || []

    # Parse scheduled time
    post_time = if scheduled_time.is_a?(String)
                  Time.zone.parse(scheduled_time)
                else
                  scheduled_time
                end

    # Get or create social account
    account = @user.social_accounts.find_by(platform: platform)
    unless account
      return { status: "error", error: "No connected #{platform} account. Please connect your account first." }
    end

    # Create scheduled post
    scheduled_post = ScheduledPost.create!(
      user: @user,
      social_account: account,
      content: content,
      scheduled_at: post_time,
      status: "scheduled"
    )

    {
      status: "success",
      post_id: scheduled_post.id,
      platform: platform,
      scheduled_at: post_time.iso8601,
      message: "Post scheduled for #{post_time.strftime('%B %d, %Y at %H:%M')}!"
    }
  rescue => e
    { status: "error", error: e.message }
  end

  def create_campaign(args)
    name = args["name"]
    description = args["description"]
    target_audience = args["target_audience"]
    budget = args["budget"]
    start_date = args["start_date"]
    end_date = args["end_date"]

    campaign = Campaign.create!(
      user: @user,
      name: name,
      description: description,
      target_audience: target_audience,
      budget: budget,
      start_date: start_date,
      end_date: end_date,
      status: "active"
    )

    {
      status: "success",
      campaign_id: campaign.id,
      name: name,
      message: "Campaign '#{name}' created successfully!"
    }
  rescue => e
    { status: "error", error: e.message }
  end

  def analyze_performance(args)
    timeframe = args["timeframe"] || "30days"
    platform = args["platform"] || "all"
    metric_type = args["metric_type"] || "overview"

    # Calculate date range
    days = case timeframe
           when "7days" then 7
           when "30days" then 30
           when "90days" then 90
           when "year" then 365
           else 30
           end

    start_date = days.ago

    # Get metrics
    metrics = if platform == "all"
                @user.performance_metrics.where("date >= ?", start_date)
              else
                @user.performance_metrics.joins(:social_account)
                     .where("social_accounts.platform = ?", platform)
                     .where("performance_metrics.date >= ?", start_date)
              end

    total_impressions = metrics.sum(:impressions)
    total_engagements = metrics.sum(:engagements)
    avg_engagement_rate = total_impressions > 0 ? (total_engagements.to_f / total_impressions * 100).round(2) : 0

    {
      status: "success",
      timeframe: timeframe,
      platform: platform,
      impressions: total_impressions,
      engagements: total_engagements,
      engagement_rate: avg_engagement_rate,
      message: "In the last #{days} days: #{total_impressions} impressions, #{total_engagements} engagements (#{avg_engagement_rate}% engagement rate)"
    }
  rescue => e
    { status: "error", error: e.message }
  end

  def format_result(tool_name, result)
    {
      tool: tool_name,
      status: result[:status],
      data: result.except(:status, :error),
      message: result[:message]
    }.compact
  end

  def format_error(tool_name, error_message)
    {
      tool: tool_name,
      status: "error",
      error: error_message,
      message: "Sorry, I encountered an error: #{error_message}"
    }
  end
end
