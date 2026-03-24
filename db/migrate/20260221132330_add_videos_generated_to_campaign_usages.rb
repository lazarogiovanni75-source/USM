class AddVideosGeneratedToCampaignUsages < ActiveRecord::Migration[7.2]
  def change
    add_column :campaign_usages, :videos_generated, :integer, default: 0

  end
end
