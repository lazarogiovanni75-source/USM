# frozen_string_literal: true

class AddPostformePostIdToScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_posts, :postforme_post_id, :string
  end
end
