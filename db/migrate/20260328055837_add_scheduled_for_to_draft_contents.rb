class AddScheduledForToDraftContents < ActiveRecord::Migration[7.1]
  def change
    add_column :draft_contents, :scheduled_for, :datetime unless column_exists?(:draft_contents, :scheduled_for)
    add_column :draft_contents, :approved_at,   :datetime unless column_exists?(:draft_contents, :approved_at)
    add_column :draft_contents, :posted_at,     :datetime unless column_exists?(:draft_contents, :posted_at)
  end
end
