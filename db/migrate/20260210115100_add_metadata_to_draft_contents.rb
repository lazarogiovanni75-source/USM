# frozen_string_literal: true

class AddMetadataToDraftContents < ActiveRecord::Migration[7.2]
  def change
    add_column :draft_contents, :metadata, :jsonb, default: {}
  end
end
