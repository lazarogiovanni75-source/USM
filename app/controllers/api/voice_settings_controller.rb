module Api
  class VoiceSettingsController < ApplicationController
    before_action :authenticate_user!

    def create
      @voice_setting = current_user.voice_settings.first_or_initialize
      
      # Handle TTS enabled toggle (safely handle missing column)
      if params.key?(:tts_enabled) && @voice_setting.respond_to?(:tts_enabled=)
        @voice_setting.tts_enabled = params[:tts_enabled] == true || params[:tts_enabled] == 'true'
      end
      
      # Handle language selection (safely handle missing column)
      if params.key?(:language) && @voice_setting.respond_to?(:language=)
        @voice_setting.language = params[:language]
      end
      
      # Handle voice_id
      if params.key?(:voice_id)
        @voice_setting.voice_id = params[:voice_id]
      end
      
      # Handle tone
      if params.key?(:tone)
        @voice_setting.tone = params[:tone]
      end
      
      # Handle speed
      if params.key?(:speed)
        @voice_setting.speed = params[:speed]
      end
      
      # Also allow enabled param if present
      if params.key?(:enabled)
        @voice_setting.enabled = params[:enabled] == true || params[:enabled] == 'true'
      end

      if @voice_setting.save
        render json: { success: true }
      else
        render json: { success: false, error: @voice_setting.errors.full_messages.join(', ') }, status: :unprocessable_entity
      end
    end
  end
end
