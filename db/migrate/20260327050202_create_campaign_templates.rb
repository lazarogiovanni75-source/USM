class CreateCampaignTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :campaign_templates do |t|
      t.string  :name,        null: false
      t.string  :category
      t.text    :description
      t.jsonb   :structure,   default: {}
      t.boolean :active,      default: true
      t.integer :post_count,  default: 0
      t.timestamps
    end
  end
end
