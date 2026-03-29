class AddOnboardingToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_steps, :text, default: '{}'
    add_column :users, :assistant_enabled, :boolean, default: true
  end
end
