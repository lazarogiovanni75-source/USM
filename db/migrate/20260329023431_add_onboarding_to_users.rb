class AddOnboardingToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :onboarding_completed_at, :datetime unless column_exists?(:users, :onboarding_completed_at)
    add_column :users, :onboarding_steps,        :text,    default: '{}' unless column_exists?(:users, :onboarding_steps)
    add_column :users, :assistant_enabled,       :boolean, default: true unless column_exists?(:users, :assistant_enabled)
  end
end
