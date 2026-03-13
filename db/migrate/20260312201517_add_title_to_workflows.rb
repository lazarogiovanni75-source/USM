class AddTitleToWorkflows < ActiveRecord::Migration[7.2]
  def change
    add_column :workflows, :title, :string

  end
end
