class AddCustomPromptAndFormatToAiContents < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_generated_contents, :custom_system_prompt, :text
    add_column :ai_generated_contents, :output_format, :string, default: 'short_form'
    add_column :ai_generated_contents, :is_edited, :boolean, default: false

    # Add indexes for new fields
    add_index :ai_generated_contents, :output_format
    add_index :ai_generated_contents, :is_edited
  end
end
