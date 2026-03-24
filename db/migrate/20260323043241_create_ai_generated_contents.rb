class CreateAiGeneratedContents < ActiveRecord::Migration[7.2]
  def change
    create_table :ai_generated_contents do |t|
      t.string :topic, null: false
      t.string :brand_voice, default: 'professional'
      t.string :platform, null: false
      t.string :content_type, default: 'caption'
      t.text :caption
      t.text :blog_post
      t.text :ad_copy
      t.text :hashtags
      t.text :thread_story
      t.text :email_marketing
      t.text :additional_context
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :ai_generated_contents, [:user_id, :created_at]
    add_index :ai_generated_contents, :platform
    add_index :ai_generated_contents, :content_type
  end
end
