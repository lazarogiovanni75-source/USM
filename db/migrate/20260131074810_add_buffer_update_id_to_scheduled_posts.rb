class AddBufferUpdateIdToScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_posts, :buffer_update_id, :string

  end
end
