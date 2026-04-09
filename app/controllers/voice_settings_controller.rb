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
    @voice_setting.enabled = params[:enabled] == 'true' if params[:enabled].present?

    if @voice_setting.save
      flash[:notice] = "Voice settings updated"
    else
      flash[:alert] = @voice_setting.errors.full_messages.join(', ')
    end

    redirect_to voice_settings_path
  end
end
