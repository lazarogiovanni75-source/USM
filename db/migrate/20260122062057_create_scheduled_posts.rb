class CreateScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    create_table :scheduled_posts do |t|
      t.references :content
      t.references :social_account
      t.references :user
      t.datetime :scheduled_at
      t.string :status, default: "pending"
      t.datetime :posted_at
      t.string :platform_post_id


      t.timestamps
    end
  end
end
