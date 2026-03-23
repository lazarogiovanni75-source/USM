class AddErrorMessageToScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_posts, :error_message, :text
  end
end
