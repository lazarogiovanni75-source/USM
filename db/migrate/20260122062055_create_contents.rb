class CreateContents < ActiveRecord::Migration[7.2]
  def change
    create_table :contents do |t|
      t.references :campaign
      t.references :user
      t.string :title, default: "Untitled"
      t.text :body
      t.string :content_type, default: "text"
      t.string :platform, default: "instagram"
      t.text :media_urls
      t.string :status, default: "draft"
      t.json :engagement_metrics, default: {}


      t.timestamps
    end
  end
end
