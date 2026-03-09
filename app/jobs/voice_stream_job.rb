# frozen_string_literal: true

# VoiceStreamJob - handles STT, orchestrates AI, handles TTS
#
# Responsibilities:
# 1. Speech-to-text transcription (with retry on 503 errors)
# 2. Call ConversationOrchestrator for AI processing
# 3. Text-to-speech playback (if needed)
#
# Usage:
#   VoiceStreamJob.perform_later(
#     stream_name: 'voice_chat_123',
#     prompt: "User message or audio_base64",
#     system: "System prompt...",
#     conversation_id: 123,
#     user_id: 456,
#     enable_tools: true
#   )

class VoiceStreamJob < ApplicationJob
  queue_as :llm

  retry_on Net::ReadTimeout, wait: 5.seconds, attempts: 3
  retry_on StandardError, wait: 5.seconds, attempts: 2

  # Event types
  TRANSCRIPT_PARTIAL = 'transcript_partial'
  TRANSCRIPT_FINAL = 'transcript_final'
  ASSISTANT_TOKEN = 'assistant_token'
  ASSISTANT_COMPLETE = 'assistant_complete'
  ERROR = 'error'

  def perform(stream_name:, prompt:, system: nil, conversation_id: nil, user_id: nil, enable_tools: true, user_stream_name: nil, **options)
    @stream_name = stream_name
    @user_stream_name = user_stream_name || stream_name
    @conversation_id = conversation_id
    @user_id = user_id

    Rails.logger.info "[VoiceStreamJob] Starting for conversation #{conversation_id}"

    # Handle speech-to-text if prompt appears to be audio
    processed_prompt = process_speech_to_text(prompt)

    return if processed_prompt.blank?

    # Call ConversationOrchestrator for AI processing
    process_with_orchestrator(
      prompt: processed_prompt,
      system: system,
      enable_tools: enable_tools
    )
  rescue => e
    Rails.logger.error "[VoiceStreamJob] perform failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    broadcast(type: ERROR, payload: { error: e.message })
    raise
  end

  private

  # Broadcast to both conversation-specific and user-level channels
  def broadcast_to_channels(event)
    # Broadcast to conversation-specific channel
    ActionCable.server.broadcast(@stream_name, event) if @stream_name
    # Also broadcast to user-level channel so frontend can receive
    ActionCable.server.broadcast(@user_stream_name, event) if @user_stream_name && @user_stream_name != @stream_name
  rescue => e
    Rails.logger.error "[VoiceStreamJob] Broadcast error: #{e.message}"
  end

  # Process speech-to-text if needed
  def process_speech_to_text(prompt)
    # Safety check: if prompt is actually audio data (starts with data:audio), don't try to transcribe
    # The controller should have already transcribed it
    if prompt.to_s.start_with?('data:audio') || prompt.to_s.start_with?('base64:')
      Rails.logger.warn "[VoiceStreamJob] Received unexpected audio data in process_speech_to_text"
      broadcast(type: ERROR, payload: { error: "Invalid prompt: expected text, got audio data" })
      return ""
    end
    
    # The prompt should already be transcribed text from the controller
    # Just use it directly without trying to re-transcribe
    broadcast(type: TRANSCRIPT_FINAL, payload: { transcript: prompt })
    prompt
  end

  # Retry on transient 503 errors from Clacky/Whisper
  def transcribe_with_retry(audio_data, retries = 3)
    Rails.logger.info "[VoiceStreamJob] Attempting transcription (retries: #{retries})"

    transcribe_audio(audio_data)
  rescue => e
    error_msg = e.message.downcase

    # Retry on 503 service unavailable or network errors
    if (error_msg.include?('503') || error_msg.include?('service unavailable') || error_msg.include?('connection')) && retries > 0
      Rails.logger.warn "[VoiceStreamJob] Transcription failed, retrying: #{e.message}"
      sleep(2)
      transcribe_with_retry(audio_data, retries - 1)
    elsif retries > 0 && error_msg.include?('timeout')
      Rails.logger.warn "[VoiceStreamJob] Transcription timeout, retrying: #{e.message}"
      sleep(1)
      transcribe_with_retry(audio_data, retries - 1)
    else
      Rails.logger.error "[VoiceStreamJob] Transcription failed after retries: #{e.message}"
      broadcast(type: ERROR, payload: { error: "Transcription failed: #{e.message}" })
      nil
    end
  end

  # Transcribe audio using OpenAI Whisper
  def transcribe_audio(audio_data)
    require 'httparty'
    require 'base64'
    require 'stringio'
    
    api_key = ENV['OPENAI_API_KEY'] || ENV['CLACKY_OPENAI_API_KEY']
    
    # Extract base64 data
    audio_base64 = audio_data.sub(/^data:audio\/\w+;base64,/, '')
    audio_bytes = Base64.decode64(audio_base64)
    
    # Create temp file
    require 'tempfile'
    temp_file = Tempfile.new(['audio', '.webm'], binmode: true)
    temp_file.write(audio_bytes)
    temp_file.close
    
    begin
      # Use HTTParty to call OpenAI Whisper API directly
      response = HTTParty.post(
        'https://api.openai.com/v1/audio/transcriptions',
        {
          headers: {
            'Authorization' => "Bearer #{api_key}"
          },
          multipart: true,
          body: {
            file: File.open(temp_file.path),
            model: 'whisper-1',
            response_format: 'text'
          },
          timeout: 60
        }
      )
      
      if response.success?
        transcript = response.body.strip
        broadcast(type: TRANSCRIPT_FINAL, payload: { transcript: transcript })
        Rails.logger.info "[VoiceStreamJob] Transcription successful: #{transcript[0..50]}..."
        transcript
      else
        raise "Whisper API error: #{response.code} - #{response.body}"
      end
    rescue => e
      Rails.logger.error "[VoiceStreamJob] Transcription error: #{e.message}"
      broadcast(type: ERROR, payload: { error: "Transcription failed: #{e.message}" })
      raise
    ensure
      temp_file.unlink
    end
  end

  # Process with ConversationOrchestrator
  def process_with_orchestrator(prompt:, system:, enable_tools:)
    Rails.logger.info "[VoiceStreamJob] process_with_orchestrator called - prompt: #{prompt[0..50]}, stream_name: #{@stream_name}, user_stream_name: #{@user_stream_name}, conversation_id: #{@conversation_id}"
    
    return broadcast(type: ERROR, payload: { error: "User not found" }) unless @user_id
    return broadcast(type: ERROR, payload: { error: "Conversation not found" }) unless @conversation_id

    user = User.find_by(id: @user_id)
    return broadcast(type: ERROR, payload: { error: "User not found" }) unless user

    conversation = AiConversation.find_by(id: @conversation_id)
    return broadcast(type: ERROR, payload: { error: "Conversation not found" }) unless conversation

    response_content = ""

    # Pass block for streaming - orchestrator yields { delta: "...", conversation_id: ... }
    Rails.logger.info "[VoiceStreamJob] Calling ConversationOrchestrator.run with stream_name: #{@stream_name}, user_id: #{@user_id}"
    
    # Also broadcast that AI is processing
    broadcast(type: 'processing', payload: { message: 'AI is thinking...' })
    
    begin
      result = ConversationOrchestrator.run(
        conversation_id: @conversation_id,
        content: prompt,
        modality: "voice",
        system_prompt: system,
        enable_tools: enable_tools,
        user: user,
        stream_name: @stream_name
      ) do |chunk_data|
        # chunk_data is now a Hash: { delta: "...", conversation_id: ... }
        delta = chunk_data[:delta] || chunk_data[:content] || ""
        response_content += delta
        Rails.logger.info "[VoiceStreamJob] Received chunk, delta length: #{delta.length}, total: #{response_content.length}"
        broadcast(type: ASSISTANT_TOKEN, payload: { content: delta })
      end
    rescue => orchestrator_error
      Rails.logger.error "[VoiceStreamJob] Orchestrator error: #{orchestrator_error.message}"
      Rails.logger.error orchestrator_error.backtrace.first(5).join("\n")
      broadcast(type: ERROR, payload: { error: "AI processing failed: #{orchestrator_error.message}" })
      return
    end

    # If result is nil (no block given), check if response_content was captured
    response_content ||= ""
    Rails.logger.info "[VoiceStreamJob] Orchestrator completed, response length: #{response_content.length}, result: #{result.inspect[0..100]}"

    # Handle TTS playback if enabled
    handle_tts_playback(response_content) if enable_tools

    broadcast(type: ASSISTANT_COMPLETE, payload: { content: response_content })
  rescue StandardError => e
    Rails.logger.error "[VoiceStreamJob] process_with_orchestrator failed: #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    broadcast(type: ERROR, payload: { error: e.message })
    raise
  end

  # Handle text-to-speech playback
  def handle_tts_playback(text)
    # Skip TTS for tool execution results
    return if text.blank? || text.include?('tool') || text.include?('executing')

    # Generate TTS audio
    begin
      require 'httparty'
      require 'base64'
      
      api_key = ENV['OPENAI_API_KEY'] || ENV['CLACKY_OPENAI_API_KEY']
      
      # Use gpt-4o-mini-tts for premium quality voice (same as voice_chat_controller)
      # Available voices: alloy, echo, fable, onyx, nova, shimmer
      voice = ENV['OTTO_VOICE'] || 'alloy'
      
      response = HTTParty.post(
        'https://api.openai.com/v1/audio/speech',
        {
          headers: {
            'Authorization' => "Bearer #{api_key}",
            'Content-Type' => 'application/json'
          },
          body: {
            model: 'gpt-4o-mini-tts',
            voice: voice,
            input: text,
            speed: 1.0,
            response_format: 'mp3'
          }.to_json,
          timeout: 60
        }
      )
      
      if response.success?
        audio_base64 = Base64.encode64(response.body)
        broadcast(type: 'tts_audio', payload: { audio: audio_base64, format: 'mp3' })
      else
        Rails.logger.warn "[VoiceStreamJob] TTS generation failed: #{response.code}"
      end
    rescue => e
      Rails.logger.warn "[VoiceStreamJob] TTS generation failed: #{e.message}"
      # Don't fail the whole request for TTS errors
    end
  end

  # Broadcast standardized event to frontend
  def broadcast(type:, payload: {})
    # Use flat structure for compatibility with frontend handlers
    # Frontend expects: { type: '...', content: '...' }
    event = {
      type: type,
      conversation_id: @conversation_id,
      timestamp: Time.now.to_i
    }
    
    # Merge payload content at top level for frontend compatibility
    event.merge!(payload)
    
    # Broadcast to BOTH channels for frontend compatibility
    broadcast_to_channels(event)
  rescue => e
    Rails.logger.error "[VoiceStreamJob] Broadcast error: #{e.message}"
  end
end
