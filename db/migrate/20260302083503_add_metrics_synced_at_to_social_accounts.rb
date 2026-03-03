class AddMetricsSyncedAtToSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :social_accounts, :metrics_synced_at, :timestamp

  end
end
