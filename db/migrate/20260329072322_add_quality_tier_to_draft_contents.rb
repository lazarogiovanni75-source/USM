class AddQualityTierToDraftContents < ActiveRecord::Migration[7.2]
  def change
    add_column :draft_contents, :quality_tier, :string, default: "standard"
    add_column :draft_contents, :credit_cost, :integer, default: 1

  end
end
