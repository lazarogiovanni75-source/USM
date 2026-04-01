class AddAllMissingUserColumns < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(:users, :brand_voice)
      add_column :users, :brand_voice, :text
    end
    unless column_exists?(:users, :brand_voice_examples)
      add_column :users, :brand_voice_examples, :text
    end
    unless column_exists?(:users, :onboarding_complete)
      add_column :users, :onboarding_complete, :boolean, default: false
    end
    unless column_exists?(:users, :quality_tier)
      add_column :users, :quality_tier, :string, default: 'standard'
    end
    unless column_exists?(:users, :assistant_enabled)
      add_column :users, :assistant_enabled, :boolean, default: true
    end
    unless column_exists?(:users, :approved)
      add_column :users, :approved, :boolean, default: false
    end
  end
end
