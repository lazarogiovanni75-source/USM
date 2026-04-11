class AddContentToWorkflows < ActiveRecord::Migration[7.1]
  def change
    add_column :workflows, :content, :text unless column_exists?(:workflows, :content)
    add_column :workflows, :title, :string unless column_exists?(:workflows, :title)
    add_column :workflows, :error_message, :text unless column_exists?(:workflows, :error_message)
  end
end
