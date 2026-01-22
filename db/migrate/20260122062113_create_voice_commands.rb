class CreateVoiceCommands < ActiveRecord::Migration[7.2]
  def change
    create_table :voice_commands do |t|
      t.references :user
      t.text :command, default: "Untitled"
      t.text :transcribed_text
      t.string :status, default: "pending"
      t.text :response_text
      t.integer :campaign_id
      t.decimal :ai_confidence, default: 0.0


      t.timestamps
    end
  end
end
