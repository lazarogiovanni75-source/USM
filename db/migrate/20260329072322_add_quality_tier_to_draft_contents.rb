class AddQualityTierToDraftContents < ActiveRecord::Migration[7.1]
  def change
    add_column :draft_contents, :quality_tier, :string,  default: 'standard' unless column_exists?(:draft_contents, :quality_tier)
    add_column :draft_contents, :credit_cost,  :integer, default: 1          unless column_exists?(:draft_contents, :credit_cost)
  end
end
