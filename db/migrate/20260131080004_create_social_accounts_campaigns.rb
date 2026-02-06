class CreateSocialAccountsCampaigns < ActiveRecord::Migration[7.2]
  def change
    create_table :social_accounts_campaigns do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :social_account, null: false, foreign_key: true
      t.timestamps
    end

    add_index :social_accounts_campaigns, [:campaign_id, :social_account_id], unique: true
  end
end
