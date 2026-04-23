class CreateBrandProfilesFresh < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:brand_profiles)
      create_table :brand_profiles do |t|
        t.references :user, foreign_key: true, index: { unique: true }
        t.string :business_name
        t.string :industry
        t.string :website_url
        t.text :products_services
        t.string :content_tone
        t.text :posting_topics
        t.text :topics_to_avoid
        t.boolean :onboarding_completed, default: false
        t.datetime :onboarding_dismissed_at
        t.integer :onboarding_step, default: 0

        t.timestamps
      end
      
      add_index :brand_profiles, [:user_id, :onboarding_completed]
    end
  end
end
