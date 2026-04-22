class AddVoiceModeToVoiceSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :voice_settings, :voice_mode, :string, default: 'auto', if_not_exists: true
  end
end
