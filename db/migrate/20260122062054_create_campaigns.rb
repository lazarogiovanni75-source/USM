class CreateCampaigns < ActiveRecord::Migration[7.2]
  def change
    create_table :campaigns do |t|
      t.string :name, default: "Untitled"
      t.text :description
      t.references :user
      t.string :status, default: "draft"
      t.string :goal
      t.string :campaign_type, default: "general"


      t.timestamps
    end
  end
end
