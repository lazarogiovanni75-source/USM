class AddAssetCountsToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :video_count, :integer, default: 2
    add_column :campaigns, :image_count, :integer, default: 3

  end
end
