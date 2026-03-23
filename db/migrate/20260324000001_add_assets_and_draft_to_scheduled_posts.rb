class AddAssetsAndDraftToScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_posts, :image_url, :string
    add_column :scheduled_posts, :video_url, :string
    add_column :scheduled_posts, :asset_url, :string
    add_column :scheduled_posts, :target_platforms, :jsonb

  end
end
