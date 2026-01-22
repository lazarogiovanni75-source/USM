class VoiceCommandsController < ApplicationController
  before_action :authenticate_user!

  def index
    @voice_commands = current_user.voice_commands.order(created_at: :desc)
  end

  private
  # Write your private methods here
end
