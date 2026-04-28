# frozen_string_literal: true

# Emergency migration fix - accessible without authentication
class MigrationFixController < ApplicationController
  skip_before_action :verify_authenticity_token, :authenticate_user!
  before_action :verify_secret_key, only: [:run]

  # GET /migration-fix?secret=<MIGRATION_SECRET_KEY>
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

    # Record migrations
    begin
      ActiveRecord::Base.connection.execute("INSERT INTO schema_migrations (version) VALUES ('20260423000001'), ('20260423000002') ON CONFLICT (version) DO NOTHING;")
      results << "✅ migrations recorded"
    rescue => e
      results << "⚠️ migration record skipped: #{e.message[0..100]}"
    end

    render html: <<~HTML.html_safe
      <html>
      <body style='font-family:monospace;padding:20px;background:#111;color:#0f0;'>
        <h2 style='color:#4f4;'>🛠️ Migration Fix Results</h2>
        <pre style='background:#1a1a1a;padding:15px;border-radius:8px;'>#{results.join("\n")}</pre>
        <p style='margin-top:20px;'><a href='/' style='color:#4af;font-size:18px;'>← Go to Dashboard</a></p>
      </body>
      </html>
    HTML
  rescue => e
    render html: "<html><body style='font-family:monospace;padding:20px;background:#111;color:#f44;'><h2>❌ Error</h2><pre>#{e.message}\n#{e.backtrace[0..5].join("\n")}</pre></body></html>".html_safe, status: 500
  end

  private

  def verify_secret_key
    expected_key = ENV.fetch('MIGRATION_SECRET_KEY', nil)
    return if expected_key.present? && params[:secret] == expected_key
    render html: "<html><body style='font-family:monospace;padding:20px;background:#111;color:#f44;'><h2>❌ Invalid Secret</h2></body></html>".html_safe and return
  end
end