class RemoveBrandVoiceFromUsers < ActiveRecord::Migration[7.2]

  def change
    remove_column :users, :brand_voice_summary, :text if column_exists?(:users, :brand_voice_summary)
    remove_column :users, :brand_voice_examples, :text if column_exists?(:users, :brand_voice_examples)
    remove_column :users, :brand_voice_answers, :text if column_exists?(:users, :brand_voice_answers)
    remove_column :users, :brand_voice_document, :text if column_exists?(:users, :brand_voice_document)
    remove_column :users, :brand_voice_generated_at, :datetime if column_exists?(:users, :brand_voice_generated_at)
    remove_column :users, :brand_voice, :text if column_exists?(:users, :brand_voice)
  end

end
