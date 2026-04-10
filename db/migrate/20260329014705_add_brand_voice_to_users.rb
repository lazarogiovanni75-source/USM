class AddBrandVoiceToUsers < ActiveRecord::Migration[7.1]

  def change

    add_column :users, :brand_voice_summary, :text

    add_column :users, :brand_voice_examples, :text

    add_column :users, :brand_voice_answers, :text

    add_column :users, :brand_voice_document, :text

    add_column :users, :brand_voice_generated_at, :datetime

  end

end
