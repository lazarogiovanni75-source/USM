class AddMetricsToSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :social_accounts, :likes, :integer
    add_column :social_accounts, :views, :integer
    add_column :social_accounts, :engagement, :integer
    add_column :social_accounts, :shares, :integer
    add_column :social_accounts, :followers, :integer
    add_column :social_accounts, :new_followers, :integer
    add_column :social_accounts, :unfollowers, :integer
    add_column :social_accounts, :messages, :integer

  end
end
