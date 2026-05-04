class ConvertAccessRequestsToPolymorphicRequestable < ActiveRecord::Migration[8.1]
  def up
    add_column :access_requests, :requestable_type, :string
    add_column :access_requests, :requestable_id, :bigint
    add_column :access_requests, :cancelled_at, :datetime

    execute <<~SQL.squish
      UPDATE access_requests
      SET requestable_type = 'Document', requestable_id = document_id
      WHERE document_id IS NOT NULL
    SQL

    execute <<~SQL.squish
      UPDATE access_requests
      SET requestable_type = 'Project', requestable_id = project_id
      WHERE requestable_type IS NULL AND project_id IS NOT NULL
    SQL

    change_column_null :access_requests, :requestable_type, false
    change_column_null :access_requests, :requestable_id, false

    remove_reference :access_requests, :project, foreign_key: true
    remove_reference :access_requests, :document, foreign_key: true

    add_index :access_requests, [:requestable_type, :requestable_id]
    add_index :access_requests, :approved_at
    add_index :access_requests, :rejected_at
    add_index :access_requests,
      [:requester_id, :requestable_type, :requestable_id, :requested_access_level, :status],
      name: "index_access_requests_unique_pending",
      unique: true,
      where: "status = 0"
  end

  def down
    add_reference :access_requests, :project, foreign_key: true
    add_reference :access_requests, :document, foreign_key: true

    execute <<~SQL.squish
      UPDATE access_requests
      SET project_id = requestable_id
      WHERE requestable_type = 'Project'
    SQL

    execute <<~SQL.squish
      UPDATE access_requests
      SET document_id = requestable_id
      WHERE requestable_type = 'Document'
    SQL

    remove_index :access_requests, name: "index_access_requests_unique_pending"
    remove_index :access_requests, [:requestable_type, :requestable_id]
    remove_index :access_requests, :approved_at
    remove_index :access_requests, :rejected_at

    remove_column :access_requests, :cancelled_at
    remove_column :access_requests, :requestable_id
    remove_column :access_requests, :requestable_type
  end
end
