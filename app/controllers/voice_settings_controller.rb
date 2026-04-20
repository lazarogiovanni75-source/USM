class VoiceSettingsController < ApplicationController
  before_action :authenticate_user!

  def show
    @voice_setting = current_user.voice_settings.first_or_initialize
  end

  def edit
    @voice_setting = current_user.voice_settings.first_or_initialize
  end

  def update
    @voice_setting = current_user.voice_settings.first_or_initialize
    
    # Handle TTS enabled toggle
    if params.key?(:tts_enabled)
      @voice_setting.tts_enabled = params[:tts_enabled] == true || params[:tts_enabled] == 'true'
    end
    
    # Handle language selection
    if params.key?(:language)
      @voice_setting.language = params[:language]
    end
    
    # Also allow enabled param if present
    if params.key?(:enabled)
      @voice_setting.enabled = params[:enabled] == true || params[:enabled] == 'true'
    end

    if @voice_setting.save
      flash[:notice] = "Voice settings updated"
    else
      flash[:alert] = @voice_setting.errors.full_messages.join(', ')
    end

    redirect_to voice_settings_path
  end
end
