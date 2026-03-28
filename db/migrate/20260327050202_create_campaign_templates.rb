class CreateCampaignTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :campaign_templates do |t|
      t.string :name
      t.text :description
      t.integer :duration_days
      t.jsonb :structure
      t.boolean :is_active
      t.string :category

      t.timestamps
    end
  end
end
