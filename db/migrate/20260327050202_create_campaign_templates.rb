class CreateCampaignTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :campaign_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.jsonb :content_structure, default: {}
      t.jsonb :platform_config, default: {}
      t.string :frequency, default: 'daily'
      t.boolean :active, default: true
      t.datetime :last_generated_at
      t.integer :total_generated, default: 0

      t.timestamps
    end

    add_index :campaign_templates, :user_id
    add_index :campaign_templates, :active
    add_index :campaign_templates, :frequency
  end
end
