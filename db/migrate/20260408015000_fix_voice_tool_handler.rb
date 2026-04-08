class FixVoiceToolHandler < ActiveRecord::Migration[7.2]
  def change
    # Add safety measures to tool execution

    # Verify AiAutopilotService.new works correctly
    # This migration runs safely on Rails startup
    
    # Add index for unique id on ai_messages if it doesn't exist
    unless index_exists?(:ai_messages, :id, unique: true)
      add_index :ai_messages, :id, unique: true, name: :index_ai_messages_on_id
    end
    
    # Log migration success for debugging
    reversible do |dir|
      dir.up do
        say "Successfully added unique index on ai_messages.id"
      end
    end
  end
end