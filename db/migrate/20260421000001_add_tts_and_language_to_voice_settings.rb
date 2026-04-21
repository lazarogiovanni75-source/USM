class AddTtsAndLanguageToVoiceSettings < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:voice_settings, :tts_enabled)
      add_column :voice_settings, :tts_enabled, :boolean, default: false
    end
    unless column_exists?(:voice_settings, :language)
      add_column :voice_settings, :language, :string, default: 'en'
    end
  end
end
