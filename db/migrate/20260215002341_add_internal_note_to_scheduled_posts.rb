class AddInternalNoteToScheduledPosts < ActiveRecord::Migration[7.2]
  def change
    add_column :scheduled_posts, :internal_note, :text

  end
end
