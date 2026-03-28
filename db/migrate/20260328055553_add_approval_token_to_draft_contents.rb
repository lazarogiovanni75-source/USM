class AddApprovalTokenToDraftContents < ActiveRecord::Migration[7.2]
  def change
    add_column :draft_contents, :approval_token, :string
    add_index :draft_contents, :approval_token, unique: true
  end
end
