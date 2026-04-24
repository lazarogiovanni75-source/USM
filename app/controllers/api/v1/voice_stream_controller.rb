# frozen_string_literal: true

module Api
  module V1
    # VoiceStreamController - Handles voice interaction streaming
    # Receives audio from frontend, processes through Whisper STT, then triggers VoiceStreamJob
    class VoiceStreamController < Api::BaseController
      skip_before_action :verify_authenticity_token

      def stream
        Rails.logger.info "[VoiceStream] Request received"

        # Get user
        user = current_user
        return render_error('Unauthorized', :unauthorized) unless user

        # Extract parameters
        stream_name = params[:stream_name] || "voice_interaction_#{user.id}"
        conversation_id = params[:conversation_id]
        early_trigger = params[:early_trigger] == 'true'

        # Handle audio file
        audio_file = params[:audio]
        if audio_file.nil?
          return render_error('No audio file provided', :bad_request)
        end

        Rails.logger.info "[VoiceStream] Processing audio for user #{user.id}, stream: #{stream_name}"

        # Create or find conversation
        conversation = if conversation_id.present?
          AiConversation.find_by(id: conversation_id)
        else
          AiConversation.create!(
            user: user,
            title: "Voice Conversation #{Time.current.strftime('%H:%M')}"
          )
        end

        # Read audio data
        audio_data = audio_file.read
        audio_filename = audio_file.original_filename || 'audio.webm'
        audio_content_type = audio_file.content_type || 'audio/webm'

        # Transcribe audio using Whisper
        transcript = transcribe_audio(audio_data, audio_filename, audio_content_type)
        if transcript.blank?
          return render_error('Transcription failed - could not understand audio', :unprocessable_entity)
        end

        Rails.logger.info "[VoiceStream] Transcription: #{transcript}"

        # Broadcast transcript to frontend
        broadcast_to_frontend(stream_name, 'transcript_final', { text: transcript })

        # Enqueue job for AI processing
        VoiceStreamJob.perform_later(
          stream_name: stream_name,
          prompt: transcript,
          conversation_id: conversation.id,
          user_id: user.id,
          enable_tools: true,
          user_stream_name: stream_name
        )

        render json: {
          success: true,
          text: transcript,
          conversation_id: conversation.id
        }
      rescue => e
        Rails.logger.error "[VoiceStream] Error: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        render_error("Processing failed: #{e.message}", :internal_server_error)
      end

      private

      def transcribe_audio(audio_data, filename, content_type)
        api_key = ENV['ANTHROPIC_API_KEY'] || ENV['OPENAI_API_KEY'] || ENV['ULTIMATE_OPENAI_API_KEY']
        raise "API key not configured" if api_key.blank?

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

      def broadcast_to_frontend(stream_name, event_type, payload)
        ActionCable.server.broadcast(stream_name, { type: event_type, payload: payload })
      rescue => e
        Rails.logger.error "[VoiceStream] Broadcast error: #{e.message}"
      end

      def render_error(message, status)
        render json: { success: false, error: message }, status: status
      end
    end
  end
end
