class AddContentToWorkflows < ActiveRecord::Migration[7.2]
  def change
    add_column :workflows, :content, :text
    add_column :workflows, :title, :string
    add_column :workflows, :error_message, :text

  end
end
