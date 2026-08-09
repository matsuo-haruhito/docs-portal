# frozen_string_literal: true

class AddIndexToDocumentsSourceAuthority < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :documents, :source_authority, algorithm: :concurrently
  end
end
