class AddAiInstructionsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :ai_instructions, :text
  end
end
