class AddTtsEnabledAndLanguageToVoiceSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :voice_settings, :tts_enabled, :boolean, default: false, if_not_exists: true
    add_column :voice_settings, :language, :string, default: 'en', if_not_exists: true
  end
end
