class AddApprovalTokenToDraftContents < ActiveRecord::Migration[7.1]
  def change
    add_column :draft_contents, :approval_token, :string unless column_exists?(:draft_contents, :approval_token)
    add_column :draft_contents, :status, :string, default: 'pending' unless column_exists?(:draft_contents, :status)
    add_index  :draft_contents, :approval_token, unique: true unless index_exists?(:draft_contents, :approval_token)
  end
end
