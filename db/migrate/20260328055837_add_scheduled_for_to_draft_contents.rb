class AddScheduledForToDraftContents < ActiveRecord::Migration[7.2]
  def change
    add_column :draft_contents, :scheduled_for, :datetime
    add_index :draft_contents, :scheduled_for
  end
end
