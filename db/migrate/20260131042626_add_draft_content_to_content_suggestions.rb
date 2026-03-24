class AddDraftContentToContentSuggestions < ActiveRecord::Migration[7.2]
  def change
    add_reference :content_suggestions, :draft_content, null: false, foreign_key: true

  end
end
