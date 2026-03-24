class AddEnabledToVoiceSettings < ActiveRecord::Migration[7.2]
  def change
    add_column :voice_settings, :enabled, :boolean

  end
end
