class AddWebhookStatusToScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_posts, :webhook_status, :string, default: 'pending'
    add_column :scheduled_posts, :webhook_error, :text
    add_column :scheduled_posts, :webhook_attempts, :integer, default: 0
    add_column :scheduled_posts, :last_webhook_at, :datetime
  end
end
