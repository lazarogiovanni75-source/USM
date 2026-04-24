# frozen_string_literal: true

# VoiceLoopService - Full voice conversation loop implementation
# Handles: Whisper STT → Claude LLM → OpenAI TTS with conversation memory
class VoiceLoopService
  include ActionView::Helpers::TextHelper

  SYSTEM_PROMPT = LlmPrompts::VOICE_ASSISTANT

  attr_reader :user, :conversation_id, :conversation_history

  def initialize(user:, conversation_id: nil)
    @user = user
    @conversation_id = conversation_id || generate_conversation_id
    @conversation_history = load_conversation_history
  end

  # Step 1: Transcribe audio using Whisper
  def transcribe(audio_data, filename: 'audio.webm', content_type: 'audio/webm')
    api_key = get_openai_api_key
    raise "OPENAI_API_KEY not configured" if api_key.blank?

    uri = URI('https://api.openai.com/v1/audio/transcriptions')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 60

    boundary = "----RubyMultipart#{SecureRandom.hex(16)}"

    body = +""
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: #{content_type}\r\n"
    body << "\r\n"
    body << audio_data
    body << "\r\n"
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"model\"\r\n"
    body << "\r\n"
    body << "whisper-1\r\n"
    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"language\"\r\n"
    body << "\r\n"
    body << "en\r\n"
    body << "--#{boundary}--\r\n"

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request.body = body

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      result['text'] || ''
    else
      Rails.logger.error "Whisper API error: #{response.code} - #{response.body}"
      raise "Transcription failed: #{response.code}"
    end
  end

  # Step 2: Send to Claude with full conversation history and tools support
  def process_with_claude(user_message, tools: nil, tool_choice: 'auto')
    # Add user message to history
    conversation_history << { role: 'user', content: user_message }

    # Trim history if too long (keep last 20 messages for context)
    trimmed_history = conversation_history.last(20)

    api_key = ENV['ANTHROPIC_API_KEY']
    raise "ANTHROPIC_API_KEY not configured" if api_key.blank?

    model = ENV.fetch('ANTHROPIC_MODEL', 'claude-sonnet-4-6')

    uri = URI('https://api.anthropic.com/v1/messages')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.path)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = '2023-06-01'
    request['anthropic-dangerous-direct-browser-access'] = 'true'

    # Build request body
    request_body = {
      model: model,
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: trimmed_history
    }

    # Add tool support if tools are provided
    if tools.present?
      request_body[:tools] = tools
      request_body[:tool_choice] = { type: tool_choice }
    end

    request.body = request_body.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)

      # Check if Claude wants to use tools
      content_blocks = result['content'] || []
      tool_use_blocks = content_blocks.select { |c| c['type'] == 'tool_use' }
      text_blocks = content_blocks.select { |c| c['type'] == 'text' }

      # If tool calls were made, execute them and return results
      if tool_use_blocks.any?
        tool_results = execute_tools_for_voice(tool_use_blocks)

        # Add assistant's tool call messages to history
        tool_use_blocks.each do |block|
          conversation_history << {
            role: 'assistant',
            content: "[tool_call] #{block['name']}: #{block['input'].to_json}"
          }
        end

        # Return tool execution results
        return {
          tool_calls_executed: true,
          results: tool_results,
          original_response: text_blocks.map { |t| t['text'] }.join(' ')
        }
      end

      claude_response = text_blocks.map { |t| t['text'] }.join(' ') || ''

      # Add assistant response to history
      conversation_history << { role: 'assistant', content: claude_response }

      # Persist updated history
      save_conversation_history

      claude_response
    else
      error_body = JSON.parse(response.body) rescue {}
      error_msg = error_body.dig('error', 'message') || response.code
      Rails.logger.error "Claude API error: #{error_msg}"
      raise "Claude error: #{error_msg}"
    end
  end

  # Execute tools for voice commands
  def execute_tools_for_voice(tool_calls)
    results = []
    tool_handler = VoiceToolHandler.new(user: @user)

    tool_calls.each do |tool_call|
      tool_name = tool_call['name']
      tool_input = tool_call['input']

      Rails.logger.info "[VoiceLoopService] Executing tool: #{tool_name} with input: #{tool_input.inspect}"

      begin
        result = tool_handler.execute(tool_name, tool_input)

        if result[:status] == "success" || result[:status] == "processing"
          results << { tool: tool_name, status: result[:status], message: result[:message] }
        else
          results << { tool: tool_name, status: "error", error: result[:error] }
        end
      rescue => e
        Rails.logger.error "[VoiceLoopService] Tool execution error: #{e.message}"
        results << { tool: tool_name, status: "error", error: e.message }
      end
    end

    results
  end

  # Step 3: Convert text to speech using OpenAI TTS
  def text_to_speech(text)
    api_key = get_openai_api_key
    raise "OPENAI_API_KEY not configured" if api_key.blank?

    uri = URI('https://api.openai.com/v1/audio/speech')

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.path)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'

    # Clean text for TTS - remove markdown formatting
    clean_text = clean_text_for_speech(text)

    request.body = {
      model: 'tts-1',           # Use tts-1 for natural voice
      voice: 'nova',            # Nova sounds conversational
      input: clean_text,
      speed: 1.0
    }.to_json

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      response.body  # Returns binary audio data
    else
      Rails.logger.error "OpenAI TTS error: #{response.code} - #{response.body}"
      raise "Text-to-speech failed: #{response.code}"
    end
  end

  # Full conversation loop: transcribe → Claude → TTS
  def full_conversation_loop(audio_data, filename: 'audio.webm', content_type: 'audio/webm')
    Rails.logger.info "VoiceLoop: Starting full conversation loop"

    # Step 1: Transcribe
    transcribed_text = transcribe(audio_data, filename: filename, content_type: content_type)
    Rails.logger.info "VoiceLoop: Transcribed - '#{transcribed_text}'"

    return { error: 'Could not transcribe audio' } if transcribed_text.blank?

    # Step 2: Process with Claude (with tools for video/image generation)
    claude_response = process_with_claude(transcribed_text, tools: AiVoiceTools::TOOLS, tool_choice: 'auto')
    Rails.logger.info "VoiceLoop: Claude response - '#{claude_response.inspect}'"

    # Handle tool execution results
    if claude_response.is_a?(Hash) && claude_response[:tool_calls_executed]
      tool_results = claude_response[:results]
      tool_summary = tool_results.map { |r| "#{r[:tool]}: #{r[:status]}" }.join(', ')

      return {
        transcribed_text: transcribed_text,
        claude_response: "I've executed the following tools: #{tool_summary}",
        tool_results: tool_results,
        conversation_id: @conversation_id,
        message_count: conversation_history.length / 2
      }
    end

    return { error: 'Claude failed to respond' } if claude_response.blank?

    # Step 3: Convert to speech (returns binary)
    # Note: For streaming, we return the text and let the caller handle TTS
    # Or we could stream the audio back directly

    {
      transcribed_text: transcribed_text,
      claude_response: claude_response,
      conversation_id: @conversation_id,
      message_count: conversation_history.length / 2  # user + assistant pairs
    }
  end

  # Reset conversation history
  def reset_conversation
    @conversation_history = []
    clear_conversation_history
    Rails.logger.info "VoiceLoop: Conversation reset"
    { success: true, conversation_id: @conversation_id }
  end

  # Get current conversation state
  def conversation_state
    {
      conversation_id: @conversation_id,
      message_count: conversation_history.length / 2,
      messages: conversation_history.map { |m| { role: m[:role], preview: truncate(m[:content], length: 50) } }
    }
  end

  private

  def generate_conversation_id
    "voice_#{SecureRandom.hex(8)}"
  end

  def load_conversation_history
    return [] unless @user.present?

    # Try to load from session or create new
    Rails.logger.info "VoiceLoop: Loading conversation history for user #{@user.id}"
    []
  end

  def save_conversation_history
    # For now, history is stored in memory
    # Could be extended to persist to database
    Rails.logger.info "VoiceLoop: Saving #{conversation_history.length} messages"
  end

  def clear_conversation_history
    session_store.clear if session_store
  end

  def session_store
    return nil unless @user.present?
    @session_store ||= {}
  end

  def get_openai_api_key
    ENV['OPENAI_API_KEY'].presence ||
      ENV['API_KEY_OPENAI'].presence ||
      Figaro.env.openai_api_key ||
      Rails.application.config_for(:application)['OPENAI_API_KEY']
  end

  def clean_text_for_speech(text)
    # Remove markdown formatting
    cleaned = text.dup

    # Remove bold/italic markers
    cleaned.gsub!(/\*\*(.+?)\*\*/, '\1')
    cleaned.gsub!(/\*(.+?)\*/, '\1')
    cleaned.gsub!(/__(.+?)__/, '\1')
    cleaned.gsub!(/_(.+?)_/, '\1')

    # Remove links but keep text
    cleaned.gsub!(/\[(.+?)\]\(.+?\)/, '\1')

    # Remove code blocks
    cleaned.gsub!(/```.+?```/m, '')
    cleaned.gsub!(/`(.+?)`/, '\1')

    # Remove bullet points and numbered lists
    cleaned.gsub!(/^[\s]*[-*]\s+/, '')
    cleaned.gsub!(/^[\s]*\d+\.\s+/, '')

    # Clean up extra whitespace
    cleaned.gsub!(/\n{3,}/, "\n\n")
    cleaned.strip!
    cleaned
  end
end
