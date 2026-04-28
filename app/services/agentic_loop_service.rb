# frozen_string_literal: true

# Agentic Loop Service - Autonomous social media content manager
# Uses Claude Sonnet 4.6 with custom tools for content generation and posting
class AgenticLoopService
  class AgenticLoopError < StandardError; end
  class BudgetExceededError < AgenticLoopError; end

  MAX_ITERATIONS = 10
  DEFAULT_MAX_BUDGET_USD = 0.50

  attr_reader :user, :run_id, :results, :total_cost, :iterations

  def initialize(user:, max_budget_usd: nil, run_id: nil)
    @user = user
    @run_id = run_id || SecureRandom.hex(8)
    @max_budget_usd = max_budget_usd&.to_f || DEFAULT_MAX_BUDGET_USD
    @results = { posts_processed: 0, posts_published: 0, images_generated: 0, videos_generated: 0, errors: [], tools_executed: [] }
    @total_cost = 0.0
    @iterations = 0
    @conversation_history = []
    @tool_results = {}
    @input = {}
  end

  def call
    Rails.logger.info "[AgenticLoop] Starting agent loop for user #{@user.id}, run #{@run_id}"
    posts = get_scheduled_posts
    return @results.merge(status: 'no_posts_scheduled', run_id: @run_id) if posts.empty?

    posts.each do |post|
      break if @total_cost >= @max_budget_usd
      begin
        process_post(post)
        @results[:posts_processed] += 1
      rescue BudgetExceededError => e
        Rails.logger.warn "[AgenticLoop] Budget exceeded: #{e.message}"
        @results[:errors] << { post_id: post.id, error: 'budget_exceeded' }
        break
      rescue => e
        Rails.logger.error "[AgenticLoop] Error: #{e.message}"
        @results[:errors] << { post_id: post.id, error: e.message }
      end
    end
    Rails.logger.info "[AgenticLoop] Completed run #{@run_id}, cost: $#{'%.6f' % @total_cost}"
    @results.merge(status: 'completed', run_id: @run_id, total_cost: @total_cost, iterations: @iterations)
  end

  def process_post(post)
    @iterations += 1
    Rails.logger.info "[AgenticLoop] Processing post #{post.id}"
    agent_response = run_agent(build_post_context(post))
    execute_tools(agent_response, post)
  end

  private

  def get_scheduled_posts
    ScheduledPost.joins(:content, :social_account)
      .where(user_id: @user.id)
      .where(status: :scheduled)
      .where('scheduled_at <= ?', 5.minutes.from_now)
      .where('scheduled_at >= ?', Time.current)
      .order(scheduled_at: :asc)
      .limit(10)
  end

  def run_agent(context)
    claude = ClaudeService.new(max_budget_usd: @max_budget_usd - @total_cost)
    response = claude.messages(messages: build_messages(context), system: build_system_prompt, tools: get_tool_definitions, tool_choice: { type: 'auto' }, temperature: 0.7)
    @total_cost += claude.total_cost
    @conversation_history << { role: 'user', content: context[:task_description] }
    @conversation_history << { role: 'assistant', content: response['content'], tool_calls: response['tool_calls'] }
    response
  rescue ClaudeService::BudgetExceededError => e
    raise BudgetExceededError, e.message
  rescue => e
    { 'content' => "Error: #{e.message}", 'tool_calls' => nil }
  end

  def execute_tools(response, post)
    return unless response['tool_calls'].present?
    response['tool_calls'].each do |tool_call|
      tool_name = tool_call['name']
      tool_input = tool_call['input'] || {}
      result = execute_tool(tool_name, tool_input, post)
      @tool_results[tool_name] = result
      tool_msg = { role: 'user', content: result[:success] ? "Success: #{result.inspect}" : "Failed: #{result[:error]}" }
      tool_msg[:type] = 'tool_result'
      tool_msg[:tool_use_id] = tool_call['id']
      @conversation_history << tool_msg
      @results[:tools_executed] << tool_name
    end
    run_agent({ task_description: 'Continue processing' }) if @iterations < MAX_ITERATIONS
  end

  def execute_tool(tool_name, input, post)
    case tool_name
    when 'generate_content' then execute_generate_content(input, post)
    when 'generate_image' then execute_generate_image(input, post)
    when 'generate_video' then execute_generate_video(input, post)
    when 'post_to_instagram' then execute_post_to_instagram(input, post)
    when 'post_to_linkedin' then execute_post_to_linkedin(input, post)
    when 'post_to_x' then execute_post_to_x(input, post)
    when 'get_analytics' then execute_get_analytics(input, post)
    when 'save_to_database' then execute_save_to_database(input, post)
    when 'notify_user' then execute_notify_user(input, post)
    else { success: false, error: "Unknown tool: #{tool_name}" }
    end
  rescue => e
    { success: false, error: e.message }
  end

  def execute_generate_content(input, post)
    prompt = "Generate social media post for #{input['platform'] || post.social_account.platform}. Theme: #{input['theme'] || post.content.title}. Return JSON with 'caption' and 'hashtags'."
    claude = ClaudeService.new(max_budget_usd: 0.02)
    response = claude.messages(messages: [{ role: 'user', content: prompt }])
    @total_cost += claude.total_cost
    json_match = response['content']&.match(/\{.*\}/m)
    json_match ? JSON.parse(json_match[0]).merge(success: true) : { success: false, error: 'Parse failed' }
  end

  def execute_generate_image(input, post)
    result = AtlasCloudImageService.new.generate_image(prompt: input['prompt'], model: input['model'] || 'openai/gpt-image-2/text-to-image', aspect_ratio: input['aspect_ratio'] || '1:1')
    return { success: false, error: result['error'] } unless result['task_id']
    output_url = poll_for_completion(:image, result['task_id'])
    @results[:images_generated] += 1
    { success: true, task_id: result['task_id'], image_url: output_url }
  end

  def execute_generate_video(input, post)
    result = AtlasCloudService.new.generate_video_from_text(prompt: input['prompt'], model: input['model'] || 'atlascloud/magi-1-24b', aspect_ratio: input['aspect_ratio'] || '16:9', duration: input['duration'] || 5)
    return { success: false, error: result['error'] } unless result['task_id']
    output_url = poll_for_completion(:video, result['task_id'])
    @results[:videos_generated] += 1
    { success: true, task_id: result['task_id'], video_url: output_url }
  end

  def execute_post_to_instagram(input, post)
    image_url = input['image_url'] || @tool_results.dig('generate_image', :image_url) || post.content.media_url
    return { success: false, error: 'No image' } unless image_url
    result = Social::InstagramPublisher.new(social_account: post.social_account).publish(post)
    @results[:posts_published] += 1 if result[:success]
    result
  end

  def execute_post_to_linkedin(input, post)
    result = Social::LinkedInPublisher.new(social_account: post.social_account).publish(post)
    @results[:posts_published] += 1 if result[:success]
    result
  end

  def execute_post_to_x(input, post)
    result = Social::XPublisher.new(social_account: post.social_account).publish(post)
    @results[:posts_published] += 1 if result[:success]
    result
  end

  def execute_get_analytics(input, post)
    metrics = Social::PostformePublisher.new(social_account: post.social_account).fetch_post_analytics(post)
    { success: true, metrics: metrics }
  end

  def execute_save_to_database(input, post)
    content = input['content'] || {}
    post.content.update!(body: content['caption'] || post.content.body, media_url: content['image_url'] || post.content.media_url, status: input['status'] || 'draft')
    { success: true, content_id: post.content.id }
  end

  def execute_notify_user(input, post)
    message = input['message'] || "Post '#{post.content.title}' processed"
    UserMailer.with(user: @user, post: post, message: message).deliver_later
    { success: true, message: message }
  rescue => e
    { success: false, error: e.message }
  end

  def poll_for_completion(type, task_id, max_attempts: 60)
    service = type == :image ? AtlasCloudImageService.new : AtlasCloudService.new
    method_name = type == :image ? :image_status : :task_status
    max_attempts.times do
      sleep(2)
      result = service.send(method_name, task_id)
      return result['output'] if result['status'] == 'success'
      raise AgenticLoopError, result['error'] if result['status'] == 'failed'
    end
    nil
  end

  def build_post_context(post)
    { post_id: post.id, platform: post.social_account.platform, scheduled_at: post.scheduled_at.iso8601, content_title: post.content.title, content_body: post.content.body, media_url: post.content.media_url, task_description: "Process post #{post.id} for #{post.social_account.platform}" }
  end

  def build_system_prompt
    LlmPrompts::AUTONOMOUS_MANAGER
  end

  def build_messages(context)
    return @conversation_history unless @conversation_history.empty?
    [{ role: 'user', content: "Task: Process post #{context[:post_id]} for #{context[:platform]}. Title: #{context[:content_title]}. Content: #{context[:content_body]}. Use tools to complete." }]
  end

  def get_tool_definitions
    [
      { name: 'generate_content', description: 'Generate captions and hashtags', input_schema: { type: 'object', properties: { platform: { type: 'string', enum: %w[instagram linkedin x] }, theme: { type: 'string' } }, required: ['platform'] } },
      { name: 'generate_image', description: 'Create AI images via Atlas Cloud', input_schema: { type: 'object', properties: { prompt: { type: 'string' }, model: { type: 'string' }, aspect_ratio: { type: 'string' } }, required: ['prompt'] } },
      { name: 'generate_video', description: 'Create AI videos via Atlas Cloud', input_schema: { type: 'object', properties: { prompt: { type: 'string' }, model: { type: 'string' }, duration: { type: 'integer' }, aspect_ratio: { type: 'string' } }, required: ['prompt'] } },
      { name: 'post_to_instagram', description: 'Publish to Instagram', input_schema: { type: 'object', properties: { caption: { type: 'string' }, image_url: { type: 'string' } } } },
      { name: 'post_to_linkedin', description: 'Publish to LinkedIn', input_schema: { type: 'object', properties: { caption: { type: 'string' } } } },
      { name: 'post_to_x', description: 'Publish to X (Twitter)', input_schema: { type: 'object', properties: { caption: { type: 'string' } } } },
      { name: 'get_analytics', description: 'Pull performance data', input_schema: { type: 'object', properties: { post_id: { type: 'integer' } } } },
      { name: 'save_to_database', description: 'Save results', input_schema: { type: 'object', properties: { content: { type: 'object' }, status: { type: 'string' } } } },
      { name: 'notify_user', description: 'Send notification', input_schema: { type: 'object', properties: { message: { type: 'string' } } } }
    ]
  end
end
