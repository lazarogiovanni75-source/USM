class CreateVoiceSettings < ActiveRecord::Migration[7.2]
  def change
    create_table :voice_settings, force: true do |t|
      t.belongs_to :user, null: false
      t.string :voice_id
      t.string :tone, default: "neutral"
      t.decimal :speed, default: 1.0

      t.timestamps
    end
    add_index :voice_settings, :user_id, if_not_exists: true
    add_index :voice_settings, :voice_id, if_not_exists: true
  end
end
