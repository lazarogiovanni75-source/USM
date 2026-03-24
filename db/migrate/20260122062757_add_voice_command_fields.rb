class AddVoiceCommandFields < ActiveRecord::Migration[7.2]
  def change
    # Note: command_text, status, and response_text already exist
    # Just adding the missing fields
    add_column :voice_commands, :command_type, :string
    add_column :voice_commands, :error_message, :text
  end
end
