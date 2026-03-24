class AddUserIdToScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    add_reference :scheduled_posts, :user, null: false, foreign_key: true
  end
end
