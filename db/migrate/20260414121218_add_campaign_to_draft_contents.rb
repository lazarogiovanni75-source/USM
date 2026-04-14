class AddCampaignToDraftContents < ActiveRecord::Migration[7.2]
  def change
    add_reference :draft_contents, :campaign, null: true, foreign_key: true

  end
end
