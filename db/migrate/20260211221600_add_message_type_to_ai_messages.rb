class AddMessageTypeToAiMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :ai_messages, :message_type, :string, default: "text"

  end
end
