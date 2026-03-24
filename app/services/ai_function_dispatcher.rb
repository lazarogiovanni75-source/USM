# AI Function Dispatcher - Execute tools called by GPT
#
# This service receives tool names and arguments from GPT,
# validates them, enforces risk levels, and executes actions.
#
# IMPORTANT: All inputs from GPT must be validated before execution.
# Never let GPT directly manipulate the database.
class AiFunctionDispatcher
  class InvalidArgumentsError < StandardError; end
  class ToolNotFoundError < StandardError; end
  class ConfirmationRequiredError < StandardError; end
  class ExecutionLimitError < StandardError; end

  def initialize(user:, session_id: nil, conversation_id: nil)
    @user = user
    @session_id = session_id || SecureRandom.uuid
    @conversation_id = conversation_id
    @execution_context = {}
  end

  # Dispatch a tool call to the appropriate handler
  # Returns the result of the tool execution
  # May raise ConfirmationRequiredError for high-risk tools
  def dispatch(tool_name, arguments)
    Rails.logger.info "[AiFunctionDispatcher] Executing tool: #{tool_name} with args: #{arguments.inspect}"

    # Check execution limits
    check_execution_limits!(tool_name)

    # Get risk level
    risk_level = AiToolDefinitions.risk_level(tool_name)

    # Create audit record
    audit_record = create_audit_record(tool_name, arguments, risk_level)

    begin
      # Check if confirmation is required
      if AiToolDefinitions.requires_confirmation?(@user)
        # Store for later and raise confirmation required
        @execution_context[:pending_execution] = {
          tool_name: tool_name,
          arguments: arguments,
          audit_id: audit_record.id,
          risk_level: risk_level
        }
        
        audit_record.update!(status: 'awaiting_confirmation')
        
        raise ConfirmationRequiredError.new(
          tool_name: tool_name,
          arguments: arguments,
          risk_level: risk_level,
          audit_id: audit_record.id
        )
      end

      # Execute the tool
      result = execute_tool(tool_name, arguments)
      
      # Update audit record
      audit_record.complete!(result)
      
      # Record execution for limits
      record_execution(tool_name)
      
      Rails.logger.info "[AiFunctionDispatcher] Tool #{tool_name} result: #{result.inspect}"
      result
      
    rescue => e
      audit_record.fail!(e.message) if audit_record
      Rails.logger.error "[AiFunctionDispatcher] Error executing #{tool_name}: #{e.message}"
      raise
    end
  end

  # Execute a tool without checking confirmation (for confirmed executions)
  def execute_confirmed(tool_name, arguments)
    Rails.logger.info "[AiFunctionDispatcher] Executing confirmed tool: #{tool_name}"

    # Find the pending audit record
    audit_record = AuditExecution.find_by(
      tool_name: tool_name,
      user: @user,
      status: 'awaiting_confirmation'
    )

    begin
      result = execute_tool(tool_name, arguments)
      audit_record.confirm! if audit_record
      record_execution(tool_name)
      result
    rescue => e
      audit_record.fail!(e.message) if audit_record
      raise
    end
  end

  # Check if there's a pending execution waiting for confirmation
  def pending_execution
    @execution_context[:pending_execution]
  end

  # Clear pending execution (after confirmation or rejection)
  def clear_pending!
    @execution_context[:pending_execution] = nil
  end

  private

  def check_execution_limits!(tool_name)
    session = OpenStruct.new(id: @session_id)
    
    unless ExecutionLimit.can_execute?(session, tool_name)
      raise ExecutionLimitError, "Execution limit reached. Please try again later."
    end
  end

  def record_execution(tool_name)
    session = OpenStruct.new(id: @session_id)
    ExecutionLimit.record_execution(session, tool_name, estimate_cost(tool_name))
  end

  def estimate_cost(tool_name)
    # Rough cost estimates in cents
    {
      'create_post' => 5,
      'schedule_post' => 5,
      'list_recent_posts' => 1,
      'get_campaigns' => 2,
      'get_analytics' => 3,
      'generate_content_idea' => 10,
      'get_user_stats' => 5
    }.fetch(tool_name, 5)
  end

  def create_audit_record(tool_name, arguments, risk_level)
    AuditExecution.create!(
      user: @user,
      tool_name: tool_name,
      parameters: arguments.merge(risk_level: risk_level.to_s),
      status: 'pending',
      session_id: @session_id
    )
  end

  def execute_tool(tool_name, arguments)
    case tool_name
    when "create_post"
      execute_create_post(arguments)
    when "schedule_post"
      execute_schedule_post(arguments)
    when "list_recent_posts"
      execute_list_recent_posts(arguments)
    when "get_campaigns"
      execute_get_campaigns(arguments)
    when "get_analytics"
      execute_get_analytics(arguments)
    when "generate_content_idea"
      execute_generate_content_idea(arguments)
    when "get_user_stats"
      execute_get_user_stats(arguments)
    else
      raise ToolNotFoundError, "Unknown tool: #{tool_name}"
    end
  end

  # Create a new post (draft)
  def execute_create_post(args)
    content = validate_string!(args["content"], "content", min_length: 1, max_length: 5000)
    platform = args["platform"]&.downcase

    # Validate platform if provided
    valid_platforms = %w[twitter facebook instagram linkedin]
    if platform && !valid_platforms.include?(platform)
      platform = nil
    end

    content_record = Content.create!(
      body: content,
      status: "draft",
      user: @user,
      campaign_id: @user.campaigns.first&.id
    )

    {
      success: true,
      message: "Post created successfully as draft",
      post_id: content_record.id,
      status: "draft",
      preview: content.truncate(100)
    }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: "Failed to create post: #{e.message}" }
  end

  # Schedule a post for later publication
  def execute_schedule_post(args)
    content = validate_string!(args["content"], "content", min_length: 1, max_length: 5000)
    platform = args["platform"]&.downcase
    scheduled_at = parse_datetime!(args["scheduled_at"])

    valid_platforms = %w[twitter facebook instagram linkedin]
    if platform && !valid_platforms.include?(platform)
      return { success: false, error: "Invalid platform. Valid options: #{valid_platforms.join(', ')}" }
    end

    if scheduled_at <= Time.current
      return { success: false, error: "Scheduled time must be in the future" }
    end

    social_account = @user.social_accounts.find_by(provider: platform)

    unless social_account
      return { success: false, error: "No #{platform} account connected. Please connect your #{platform} account first." }
    end

    scheduled_post = ScheduledPost.create!(
      content: content,
      scheduled_at: scheduled_at,
      social_account: social_account,
      user: @user,
      status: "pending"
    )

    {
      success: true,
      message: "Post scheduled for #{scheduled_at.in_time_zone.strftime('%B %d, %Y at %I:%M %p')}",
      post_id: scheduled_post.id,
      scheduled_at: scheduled_at.iso8601,
      platform: platform
    }
  rescue ActiveRecord::RecordInvalid => e
    { success: false, error: "Failed to schedule post: #{e.message}" }
  end

  # List recent posts/drafts
  def execute_list_recent_posts(args)
    status = args["status"]&.downcase
    limit = validate_integer!(args["limit"], "limit", min: 1, max: 50) || 10

    scope = Content.where(user: @user)

    if status.present?
      valid_statuses = %w[draft scheduled published]
      if valid_statuses.include?(status)
        scope = scope.where(status: status)
      end
    end

    posts = scope.order(created_at: :desc).limit(limit).map do |post|
      {
        id: post.id,
        body: post.body.to_s.truncate(200),
        status: post.status,
        created_at: post.created_at.iso8601,
        platform: post.social_account&.provider
      }
    end

    { posts: posts, count: posts.length }
  end

  # Get campaigns
  def execute_get_campaigns(args)
    status = args["status"]&.downcase

    scope = @user.campaigns

    if status.present?
      valid_statuses = %w[active completed draft]
      if valid_statuses.include?(status)
        scope = scope.where(status: status)
      end
    end

    campaigns = scope.order(created_at: :desc).limit(10).map do |campaign|
      {
        id: campaign.id,
        name: campaign.name,
        status: campaign.status,
        created_at: campaign.created_at.iso8601
      }
    end

    { campaigns: campaigns, count: campaigns.length }
  end

  # Get analytics
  def execute_get_analytics(args)
    metric_type = args["metric_type"] || "overview"
    days = validate_integer!(args["days"], "days", min: 1, max: 90) || 7

    from_date = days.days.ago

    metrics = EngagementMetric.where(user: @user).where("date >= ?", from_date)

    total_engagement = metrics.sum(:likes + :comments + :shares)
    total_reach = metrics.sum(:impressions)
    total_clicks = metrics.sum(:link_clicks)

    recent_posts = ScheduledPost.where(user: @user)
                              .where("scheduled_at >= ?", from_date)
                              .order(scheduled_at: :desc)
                              .limit(5)

    post_performance = recent_posts.map do |post|
      {
        content: post.content.to_s.truncate(50),
        status: post.status,
        scheduled_at: post.scheduled_at&.iso8601,
        platform: post.social_account&.provider
      }
    end

    {
      period_days: days,
      overview: {
        total_engagement: total_engagement,
        total_reach: total_reach,
        total_clicks: total_clicks
      },
      recent_posts: post_performance
    }
  rescue => e
    { error: "Failed to fetch analytics: #{e.message}" }
  end

  # Generate content ideas
  def execute_generate_content_idea(args)
    topic = validate_string!(args["topic"], "topic", min_length: 1, max_length: 500)
    platform = args["platform"]&.downcase || "any"
    count = validate_integer!(args["count"], "count", min: 1, max: 10) || 3

    prompt = <<~PROMPT
      Generate #{count} social media content ideas about "#{topic}".
      Platform: #{platform == 'any' ? 'various platforms' : platform}.
      
      For each idea, provide:
      1. A catchy title/hook
      2. The main content (tweet-length for Twitter, longer for others)
      3. 2-3 relevant hashtags
      
      Format as a JSON array of objects with keys: title, content, hashtags
    PROMPT

    ideas = LlmService.call_blocking(
      prompt: prompt,
      model: "claude-sonnet-4-6",
      temperature: 0.8
    )

    begin
      parsed = JSON.parse(ideas)
      { ideas: parsed, topic: topic, platform: platform }
    rescue
      { ideas: [{ content: ideas }], topic: topic, platform: platform }
    end
  rescue LlmService::LlmError => e
    { error: "Failed to generate ideas: #{e.message}" }
  end

  # Get user stats (admin only)
  def execute_get_user_stats(args)
    unless @user.admin?
      return { success: false, error: "Admin access required" }
    end

    period = args["period"] || "week"

    from_date = case period
    when "today" then Date.today
    when "week" then 1.week.ago
    when "month" then 1.month.ago
    else nil
    end

    user_scope = from_date ? User.where("created_at >= ?", from_date) : User.all

    {
      total_users: User.count,
      new_users: user_scope.count,
      period: period,
      active_sessions: Session.where("created_at >= ?", from_date || 1.week.ago).count
    }
  end

  # Validation helpers
  def validate_string!(value, name, min_length: nil, max_length: nil)
    raise InvalidArgumentsError, "#{name} is required" if value.blank?
    
    str = value.to_s
    raise InvalidArgumentsError, "#{name} is too short (min: #{min_length})" if min_length && str.length < min_length
    raise InvalidArgumentsError, "#{name} is too long (max: #{max_length})" if max_length && str.length > max_length
    
    str
  end

  def validate_integer!(value, name, min: nil, max: nil)
    return nil if value.nil?
    
    int = value.to_i
    raise InvalidArgumentsError, "#{name} must be a number" if value.to_s != int.to_s
    raise InvalidArgumentsError, "#{name} is too small (min: #{min})" if min && int < min
    raise InvalidArgumentsError, "#{name} is too large (max: #{max})" if max && int > max
    
    int
  end

  def parse_datetime!(value)
    return nil if value.blank?
    
    Time.parse(value)
  rescue ArgumentError
    raise InvalidArgumentsError, "Invalid datetime format. Use ISO 8601 format (e.g., '2024-06-15T14:30:00Z')"
  end
end

# Custom error for confirmation required
class ConfirmationRequiredError < StandardError
  attr_reader :tool_name, :arguments, :risk_level, :audit_id

  def initialize(tool_name:, arguments:, risk_level:, audit_id:)
    @tool_name = tool_name
    @arguments = arguments
    @risk_level = risk_level
    @audit_id = audit_id
    
    super("Confirmation required for #{tool_name}")
  end
end
