# frozen_string_literal: true

class Admin::MigrationFixController < Admin::BaseController
  # Secret endpoint to create missing tables - no auth required for emergency access
  # Access: /admin/migration-fix?secret=USM_EMERGENCY_2024
  skip_before_action :verify_authenticity_token, only: [:run]
  before_action :verify_secret_key, only: [:run]

  def run
    results = []

    # Create brand_profiles if missing
    unless ActiveRecord::Base.connection.table_exists?(:brand_profiles)
      ActiveRecord::Base.connection.create_table :brand_profiles, force: :cascade do |t|
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
      ActiveRecord::Base.connection.add_index :brand_profiles, [:user_id, :onboarding_completed], name: :index_brand_profiles_on_user_id_and_onboarding_completed
      results << "✅ brand_profiles table created"
    else
      results << "ℹ️ brand_profiles already exists"
    end

    # Create assistant_conversations if missing
    unless ActiveRecord::Base.connection.table_exists?(:assistant_conversations)
      ActiveRecord::Base.connection.create_table :assistant_conversations, force: :cascade do |t|
        t.references :user, null: false, foreign_key: true
        t.text :messages, default: '[]'
        t.string :current_page
        t.string :title
        t.timestamps
      end
      ActiveRecord::Base.connection.add_index :assistant_conversations, :user_id, name: :index_assistant_conversations_on_user_id
      results << "✅ assistant_conversations table created"
    else
      results << "ℹ️ assistant_conversations already exists"
    end

    # Record migrations to prevent future conflicts
    unless ActiveRecord::Base.connection.table_exists?(:schema_migrations)
      results << "❌ schema_migrations table not found - cannot record migrations"
    else
      ActiveRecord::Base.connection.execute("INSERT INTO schema_migrations (version) VALUES ('20260423000001'), ('20260423000002') ON CONFLICT (version) DO NOTHING;")
      results << "✅ migrations recorded in schema_migrations"
    end

    render html: "<html><body style='font-family:monospace;padding:20px;background:#1a1a1a;color:#0f0;'><h2>Migration Fix Results</h2><pre>#{results.join('\n')}</pre><p style='margin-top:20px;'><a href='/' style='color:#4af;'>← Go to Dashboard</a></p></body></html>".html_safe
  end

  private

  def verify_secret_key
    secret = params[:secret]
    # Use your app name or a known secret phrase as the key
    expected = "USM_EMERGENCY_2024"
    unless secret == expected
      render html: "<html><body style='font-family:monospace;padding:20px;background:#1a1a1a;color:#f44;'><h2>❌ Invalid Secret Key</h2><p>You need the correct secret key to access this endpoint.</p></body></html>".html_safe and return
    end
  end
end
