# This migration was previously removed but exists in production database schema_migrations table
# Creating placeholder to prevent deployment errors
class CreateSolidCableMessages < ActiveRecord::Migration[7.2]
  def change
    # This migration has already been applied in production
    # No-op to prevent "pending migration" errors
    
    # Original migration created solid_cable_messages table for ActionCable
    # Table may or may not exist depending on Rails version and ActionCable configuration
    # Safe to skip as the table structure is managed by the solid_cable gem
  end
end
