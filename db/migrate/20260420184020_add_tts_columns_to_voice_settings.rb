class AddTtsColumnsToVoiceSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :voice_settings, :tts_enabled, :boolean, default: false
    add_column :voice_settings, :language, :string, default: 'en'
  end
end
