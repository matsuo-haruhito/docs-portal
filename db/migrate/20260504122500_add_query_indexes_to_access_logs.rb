class AddQueryIndexesToAccessLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :access_logs,
              %i[accessed_at id],
              order: { accessed_at: :desc, id: :desc },
              name: "index_access_logs_on_recent_order"

    add_index :access_logs,
              %i[action_type accessed_at id],
              order: { accessed_at: :desc, id: :desc },
              name: "index_access_logs_on_action_type_recent"

    add_index :access_logs,
              %i[target_type accessed_at id],
              order: { accessed_at: :desc, id: :desc },
              name: "index_access_logs_on_target_type_recent"

    add_index :access_logs,
              %i[project_id accessed_at id],
              order: { accessed_at: :desc, id: :desc },
              name: "index_access_logs_on_project_recent"
  end
end
