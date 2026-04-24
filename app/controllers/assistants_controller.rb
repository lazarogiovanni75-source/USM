class AssistantsController < ApplicationController
  before_action :authenticate_user!
  before_action :load_or_create_conversation

  # GET /assistant - List all conversations
  def index
    conversations = current_user.assistant_conversations
      .order(updated_at: :desc)
      .limit(50)
      .map { |c| { id: c.id, title: c.title.presence || "New conversation", updated_at: c.updated_at, message_count: c.messages_array.count } }
    render json: { conversations: conversations }
  end

  # POST /assistant/chat
  def chat
    user_message = params[:message].to_s.strip
    current_page = params[:current_page] || "dashboard"
    conversation_id = params[:conversation_id]

    # Load specific conversation if provided
    if conversation_id.present?
      @conversation = current_user.assistant_conversations.find_by(id: conversation_id)
      @conversation ||= current_user.assistant_conversations.create(user: current_user)
    end

    return render json: { error: "Message required" }, status: :bad_request if user_message.blank?

    # Save user message
    @conversation.add_message!("user", user_message)
    @conversation.update!(current_page: current_page)

    # Build context-aware system prompt
    system = build_system_prompt(current_page)

    # Get conversation history for Claude
    messages = @conversation.messages_array.map do |m|
      { role: m["role"], content: m["content"] }
    end

    # Get available tools for the AI assistant
    tools = AiVoiceTools::TOOLS

    # Call Claude via LlmService with tools
    response = LlmService.chat(system: system, messages: messages, tools: tools, tool_choice: 'auto')

    # Handle tool execution if any tools were called
    reply = response[:text]
    if response[:tool_calls].present?
      tool_results = execute_tools(response[:tool_calls])
      # Add assistant's text response first
      @conversation.add_message!("assistant", reply) if reply.present?
      # Add tool results as assistant messages
      tool_results.each do |tool_result|
        @conversation.add_message!("assistant", tool_result)
      end
      # If no text reply, use the last tool result as the response
      reply = tool_results.last if reply.blank?
    else
      # Save assistant reply
      @conversation.add_message!("assistant", reply) if reply.present?
    end

    # Check if any onboarding steps were triggered
    check_onboarding_triggers(user_message)

    render json: {
      reply: reply,
      conversation_id: @conversation.id,
      conversation_title: @conversation.title,
      onboarding_progress: current_user.onboarding_progress,
      next_step: current_user.next_onboarding_step
    }
  rescue => e
    Rails.logger.error "Assistant chat error: #{e.message}"
    render json: { error: e.message }, status: :internal_server_error
  end

  # Execute tools called by the AI
  def execute_tools(tool_calls)
    results = []
    tool_handler = VoiceToolHandler.new(user: current_user)

    tool_calls.each do |tool_call|
      tool_name = tool_call[:name]
      tool_input = tool_call[:input]
      tool_id = tool_call[:id]

      Rails.logger.info "[AssistantsController] Executing tool: #{tool_name} with input: #{tool_input.inspect}"

      begin
        result = tool_handler.execute(tool_name, tool_input)

        if result[:status] == "success" || result[:status] == "processing"
          results << result[:message] || "Action completed successfully!"
        else
          results << "❌ Error: #{result[:error] || 'Something went wrong'}"
        end
      rescue => e
        Rails.logger.error "[AssistantsController] Tool execution error: #{e.message}"
        results << "❌ Error executing #{tool_name}: #{e.message}"
      end
    end

    results
  end

  # GET /assistant/:id - Load a specific conversation
  def show
    @conversation = current_user.assistant_conversations.find_by(id: params[:id])
    if @conversation.nil?
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end
    render json: {
      id: @conversation.id,
      title: @conversation.title.presence || "New conversation",
      messages: @conversation.messages_array,
      updated_at: @conversation.updated_at
    }
  end

  # DELETE /assistant/:id - Delete a conversation
  def destroy
    @conversation = current_user.assistant_conversations.find_by(id: params[:id])
    if @conversation.nil?
      render json: { error: "Conversation not found" }, status: :not_found
      return
    end
    @conversation.destroy
    render json: { success: true }
  end

  # POST /assistant/complete_step
  def complete_step
    step_key = params[:step_key]
    if OnboardingTrackable::ONBOARDING_STEPS.key?(step_key)
      current_user.complete_onboarding_step!(step_key)
      render json: { success: true, progress: current_user.onboarding_progress }
    else
      render json: { error: "Invalid step" }, status: :bad_request
    end
  end

  # DELETE /assistant/clear
  def clear
    # Create a new conversation instead of clearing
    new_conversation = current_user.assistant_conversations.create(user: current_user)
    render json: { success: true, conversation_id: new_conversation.id }
  end

  private

  def load_or_create_conversation
    @conversation = AssistantConversation.find_or_create_by(user: current_user)
  end

  def build_system_prompt(current_page)
    user = current_user
    progress = user.onboarding_progress
    next_step_key = user.next_onboarding_step
    next_step = next_step_key ? OnboardingTrackable::ONBOARDING_STEPS[next_step_key] : nil

    pending_steps = user.pending_onboarding_steps.map { |_, v| "- #{v[:label]}" }.join("\n")

    <<~PROMPT
      You are the friendly, knowledgeable AI assistant for #{Rails.application.config.x.appname} — an AI-powered social media automation platform. Your name is "AI Assistant".

      ## Your Roles
      1. **Onboarding Guide**: Help new users get set up step by step
      2. **How-To Expert**: Answer any question about app features instantly
      3. **Smart Suggester**: Proactively suggest what the user should do next based on their progress

      ## About #{Rails.application.config.x.appname} (Your Complete Knowledge Base)

      ### Core Features:
      - **AI Content Generation**: Create posts, captions, and copy using Claude AI. Go to Content → New Content.
      - **Image & Video Generation**: Generate AI images and videos using Atlas Cloud. Available in the content creator.
      - **Campaign Builder**: Create multi-post campaigns across multiple platforms. 5 templates available: 7-Day Product Launch, Holiday Sale, Brand Awareness, New Product Teaser, Weekly Engagement.
      - **Content Scheduling**: Schedule posts to go live automatically. Go to Scheduled Posts.
      - **Social Media Posting**: Post to multiple platforms: Instagram, Facebook, TikTok, LinkedIn, X (Twitter), YouTube, Pinterest, Bluesky, Threads.
      - **Post Analytics**: Track performance of all posts. Go to Analytics dashboard.
      - **Brand Voice**: Train the AI to write in your unique style. Go to Brand Voice in the menu.
      - **Voice Chat**: Talk to the AI assistant using your microphone for hands-free content creation.
      - **Claude Agentic Loop**: AI runs autonomously to manage your content pipeline.
      - **Credit System**: Credits are used for AI image/video generation. Purchase more in Billing.

      ### Subscription Tiers:
      - **Starter**: Entry level, core features
      - **Entrepreneur**: Mid tier, more posts and campaigns
      - **Pro**: Full access, unlimited features

      ### Getting Started (Key Steps):
      1. Connect a social media account (Social Accounts)
      2. Set up Brand Voice (Brand Voice in menu)
      3. Generate first content (Content → New Content)
      4. Create a campaign (Campaigns → New Campaign)
      5. Schedule a post (Scheduled Posts)

      ## Current User Context
      - **Name**: #{user.name || user.email}
      - **Plan**: #{user.subscription_plan || "Free/Trial"}
      - **Member since**: #{user.created_at.strftime("%B %d, %Y")}
      - **Current page**: #{current_page}
      - **Onboarding progress**: #{progress[:completed]}/#{progress[:total]} steps completed (#{progress[:percentage]}%)
      - **Next recommended step**: #{next_step ? next_step[:label] : "All steps complete! 🎉"}

      ### Pending Setup Steps:
      #{pending_steps.present? ? pending_steps : "All steps completed! ✅"}

      ## Your Personality
      - Warm, encouraging, and concise
      - Use emojis sparingly but effectively
      - Always give actionable next steps
      - If user seems stuck, offer to walk them through it step by step
      - Celebrate wins ("Great job connecting Instagram! 🎉")
      - Keep responses under 150 words unless a detailed how-to is needed
      - Never say "I don't know" — always suggest where to look or offer to help find out

      ## Response Format
      - Lead with the direct answer
      - Follow with 1-2 actionable steps if relevant
      - End with an offer to help further if it's a complex topic
    PROMPT
  end

  def check_onboarding_triggers(user_message)
    msg = user_message.downcase
    # Auto-complete steps based on conversation context
    if msg.include?("connected") && (msg.include?("instagram") || msg.include?("social account"))
      current_user.complete_onboarding_step!("connect_social_account")
    end
  end
end