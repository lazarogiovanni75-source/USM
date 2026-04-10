class AddBrandVoiceToUsersV2 < ActiveRecord::Migration[7.1]

  def change

    add_column :users, :brand_voice_summary, :text unless column_exists?(:users, :brand_voice_summary)

    add_column :users, :brand_voice_examples, :text unless column_exists?(:users, :brand_voice_examples)

    add_column :users, :brand_voice_answers, :text unless column_exists?(:users, :brand_voice_answers)

    add_column :users, :brand_voice_document, :text unless column_exists?(:users, :brand_voice_document)

    add_column :users, :brand_voice_generated_at, :datetime unless column_exists?(:users, :brand_voice_generated_at)

  end

end
