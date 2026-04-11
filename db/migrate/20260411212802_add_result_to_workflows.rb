class AddResultToWorkflows < ActiveRecord::Migration[7.2]
  def change
    add_column :workflows, :result, :text

  end
end
