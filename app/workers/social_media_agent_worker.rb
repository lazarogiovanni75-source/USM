# frozen_string_literal: true

# SocialMediaAgentWorker - Sidekiq worker implementing Claude agent loop
# Triggers every 5 minutes via sidekiq-cron to process scheduled posts
# Uses Postforme API exclusively for all social media posting
#
# Agent Loop Pattern:
# 1. Query database for posts scheduled in the next 5 minutes
# 2. Call Anthropic Messages API with tools array defined in Ruby
# 3. Parse Claude response - if tool_use, execute corresponding method
# 4. Send tool result back to Claude in next message
# 5. Repeat until Claude returns end_turn
#
# Uses ClaudeService for API calls and PostformeService for all posting
class SocialMediaAgentWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, backtrace: true

  MAX_ITERATIONS = 10
  MAX_BUDGET_USD = 0.50

  # Supported platforms via Postforme
  PLATFORMS = %w[instagram facebook tiktok bluesky pinterest linkedin youtube threads x].freeze

  # Tool definitions in Anthropic format
  TOOLS = [
    { name: "get_scheduled_posts", description: "Get posts scheduled in next 5 minutes", input_schema: { type: "object", properties: {} } },
    { name: "get_post_details", description: "Get post details by ID", input_schema: { type: "object", properties: { post_id: { type: "integer" } }, required: ["post_id"] } },
    { name: "generate_image", description: "Generate image via Atlas Cloud", input_schema: { type: "object", properties: { prompt: { type: "string" }, model: { type: "string" }, aspect_ratio: { type: "string" } }, required: ["prompt"] } },
    { name: "generate_video", description: "Generate video via Atlas Cloud", input_schema: { type: "object", properties: { prompt: { type: "string" }, model: { type: "string" }, duration: { type: "integer" }, aspect_ratio: { type: "string" } }, required: ["prompt"] } },
    { name: "poll_generation_status", description: "Poll Atlas Cloud for task status", input_schema: { type: "object", properties: { task_id: { type: "string" }, type: { type: "string", enum: ["image", "video"] } }, required: ["task_id", "type"] } },
    { name: "publish_via_postforme", description: "Publish post to ALL platforms via Postforme API (Instagram, Facebook, TikTok, Bluesky, Pinterest, LinkedIn, YouTube, Threads, X)", input_schema: { type: "object", properties: { post_id: { type: "integer" } }, required: ["post_id"] } },
    { name: "update_post_status", description: "Update post status in database", input_schema: { type: "object", properties: { post_id: { type: "integer" }, status: { type: "string", enum: ["draft", "scheduled", "published", "failed", "cancelled"] }, error_message: { type: "string" }, platform_post_id: { type: "string" } }, required: ["post_id", "status"] } },
    { name: "notify_user", description: "Send user notification", input_schema: { type: "object", properties: { user_id: { type: "integer" }, post_id: { type: "integer" }, status: { type: "string" }, message: { type: "string" } }, required: ["user_id", "post_id"] } },
    { name: "log_message", description: "Log message", input_schema: { type: "object", properties: { level: { type: "string", enum: ["info", "warn", "error"] }, message: { type: "string" } }, required: ["message"] } }
  ].freeze

  SYSTEM_PROMPT = "You are an autonomous social media manager. Check for scheduled posts, verify assets, generate media if needed, publish to ALL platforms via Postforme API (Instagram, Facebook, TikTok, Bluesky, Pinterest, LinkedIn, YouTube, Threads, X), update statuses, notify users. Budget: keep costs under $0.50 per run. IMPORTANT: Use publish_via_postforme for ALL social media posting - it handles all 9 platforms."

  def perform(args = {})
    Rails.logger.info "[SocialMediaAgentWorker] Starting at #{Time.current.iso8601}"

    unless claude_configured?
      Rails.logger.warn "[SocialMediaAgentWorker] Claude not configured, using simple publish"
      perform_simple_publish
      return
    end

    run_agent_loop
  rescue StandardError => e
    Rails.logger.error "[SocialMediaAgentWorker] Error: #{e.message}"
    raise
  ensure
    Rails.logger.info "[SocialMediaAgentWorker] Completed at #{Time.current.iso8601}"
  end

  private

  def claude_configured?
    ENV['ANTHROPIC_API_KEY'].present?
  end

  def postforme_configured?
    ENV['POSTFORME_API_KEY'].present?
  end

  def run_agent_loop
    client = ClaudeService.new(max_budget_usd: MAX_BUDGET_USD)
    messages = [{ role: "user", content: "Check scheduled posts and process them end-to-end. Publish all posts via Postforme API." }]
    iteration = 0

    loop do
      iteration += 1
      break if iteration > MAX_ITERATIONS

      Rails.logger.info "[SocialMediaAgentWorker] Iteration #{iteration}"

      response = client.messages(
        messages: messages,
        system: SYSTEM_PROMPT,
        tools: TOOLS,
        tool_choice: { type: 'auto' },
        temperature: 0.7
      )

      messages << { role: "assistant", content: response['content'] || "" }
      break if response['stop_reason'] == 'end_turn'

      if response['stop_reason'] == 'tool_use' && response['tool_calls'].present?
        tool_results = process_tool_calls(response['tool_calls'])
        messages << { role: "user", content: tool_results }
      end

      break if client.total_cost >= MAX_BUDGET_USD
    end

    Rails.logger.info "[SocialMediaAgentWorker] #{iteration} iterations, cost: $#{'%.6f' % client.total_cost}"
  end

  def process_tool_calls(tool_calls)
    tool_calls.map do |tool_call|
      tool_name = tool_call['name']
      tool_input = tool_call['input'] || {}
      tool_id = tool_call['id']
      result = execute_tool(tool_name, tool_input)
      format_tool_result(tool_id, tool_name, result)
    end
  rescue => e
    Rails.logger.error "[SocialMediaAgentWorker] Tool error: #{e.message}"
    []
  end

  def format_tool_result(tool_id, tool_name, result)
    content = result.is_a?(Hash) ? (result[:success] == false ? "Error: #{result[:error]}" : result.except(:success).to_s) : result.to_s
    { type: "tool_result", tool_use_id: tool_id, content: content }
  end

  def execute_tool(tool_name, input)
    case tool_name
    when "get_scheduled_posts" then execute_get_scheduled_posts
    when "get_post_details" then execute_get_post_details(input['post_id'])
    when "generate_image" then execute_generate_image(input)
    when "generate_video" then execute_generate_video(input)
    when "poll_generation_status" then execute_poll_generation_status(input['task_id'], input['type'])
    when "publish_via_postforme" then execute_publish_via_postforme(input)
    when "update_post_status" then execute_update_post_status(input)
    when "notify_user" then execute_notify_user(input)
    when "log_message" then execute_log_message(input)
    else { success: false, error: "Unknown tool: #{tool_name}" }
    end
  end

  def execute_get_scheduled_posts
    posts = ScheduledPost.joins(:content)
                         .where(status: %w[scheduled draft])
                         .where('scheduled_at <= ?', 5.minutes.from_now)
                         .where('scheduled_at >= ?', Time.current - 1.minute)
                         .includes(:content, :social_account, :user)
                         .limit(20)

    posts_data = posts.map do |post|
      {
        id: post.id,
        title: post.content.title,
        platforms: post.all_platforms,
        scheduled_at: post.scheduled_at.iso8601,
        status: post.status,
        has_media: post.has_assets?
      }
    end
    { success: true, posts: posts_data, count: posts_data.size }
  end

  def execute_get_post_details(post_id)
    post = ScheduledPost.includes(:content, :social_account).find_by(id: post_id)
    return { success: false, error: "Post #{post_id} not found" } unless post

    {
      success: true,
      post: {
        id: post.id,
        title: post.content.title,
        body: post.content.body,
        media_url: post.content.media_url,
        platforms: post.all_platforms,
        scheduled_at: post.scheduled_at.iso8601,
        status: post.status,
        user_id: post.user_id,
        has_assets: post.has_assets?
      }
    }
  end

  def execute_generate_image(input)
    result = AtlasCloudService.new.generate_image(prompt: input['prompt'], model: input['model'], aspect_ratio: input['aspect_ratio'])
    result['task_id'] ? { success: true, task_id: result['task_id'], status: 'pending' } : { success: false, error: result['error'] }
  end

  def execute_generate_video(input)
    result = AtlasCloudService.new.generate_video_from_text(prompt: input['prompt'], model: input['model'], aspect_ratio: input['aspect_ratio'], duration: input['duration'])
    result['task_id'] ? { success: true, task_id: result['task_id'], status: 'pending' } : { success: false, error: result['error'] }
  end

  def execute_poll_generation_status(task_id, type)
    service = type == 'image' ? AtlasCloudImageService.new : AtlasCloudService.new
    result = service.send(type == 'image' ? :image_status : :task_status, task_id)
    { success: true, task_id: task_id, status: result['status'], output: result['output'] }
  end

  def execute_publish_via_postforme(input)
    return { success: false, error: "Postforme API not configured" } unless postforme_configured?

    post = ScheduledPost.includes(:content, :social_account).find_by(id: input['post_id'])
    return { success: false, error: "Post #{input['post_id']} not found" } unless post

    begin
      publisher = Social::PostformePublisher.new
      result = publisher.publish(post)

      if result[:success]
        {
          success: true,
          post_id: post.id,
          postforme_post_id: result[:postforme_post_id],
          platforms_targeted: result[:platforms_targeted],
          url: result[:url],
          status: post.status
        }
      else
        {
          success: false,
          error: result[:error] || "Failed to publish via Postforme"
        }
      end
    rescue => e
      Rails.logger.error "[SocialMediaAgentWorker] Postforme publish error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def execute_update_post_status(input)
    post = ScheduledPost.find_by(id: input['post_id'])
    return { success: false, error: "Post not found" } unless post

    attrs = { status: input['status'] }
    attrs[:error_message] = input['error_message'] if input['error_message']
    attrs[:platform_post_id] = input['platform_post_id'] if input['platform_post_id']
    attrs[:posted_at] = Time.current if input['status'] == 'published'

    post.update!(attrs)

    { success: true, post_id: post.id, status: post.status }
  rescue => e
    { success: false, error: e.message }
  end

  def execute_notify_user(input)
    user = User.find_by(id: input['user_id'])
    return { success: false, error: "User not found" } unless user
    return { success: true, message: "No email" } unless user.email.present?

    post = ScheduledPost.find_by(id: input['post_id'])
    message = input['message'] || "Your post has been #{input['status'] || 'processed'}."

    if defined?(UserMailer)
      UserMailer.with(user: user, post: post, message: message).social_media_notification.deliver_later
    end

    { success: true, message: "Notification sent to #{user.email}" }
  rescue => e
    { success: false, error: e.message }
  end

  def execute_log_message(input)
    Rails.logger.send(input['level'] || 'info', "[SocialMediaAgentWorker] #{input['message']}")
    { success: true, logged: input['message'] }
  end

  # Fallback without Claude - simple publish via Postforme
  def perform_simple_publish
    return unless postforme_configured?

    due_posts = ScheduledPost.where('scheduled_at <= ?', Time.current)
                             .where(status: %w[scheduled draft])
                             .where.not(user_id: nil)
                             .includes(:content, :social_account)

    Rails.logger.info "[SocialMediaAgentWorker] Found #{due_posts.count} posts to publish"

    publisher = Social::PostformePublisher.new

    due_posts.find_each do |post|
      begin
        result = publisher.publish(post)
        if result[:success]
          Rails.logger.info "[SocialMediaAgentWorker] Published post #{post.id} via Postforme"
        else
          Rails.logger.error "[SocialMediaAgentWorker] Failed to publish post #{post.id}: #{result[:error]}"
        end
      rescue => e
        Rails.logger.error "[SocialMediaAgentWorker] Error publishing post #{post.id}: #{e.message}"
      end
    end
  end
end
