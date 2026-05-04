class AddRemainingFilterIndexesToAccessLogs < ActiveRecord::Migration[8.1]
  def change
    add_index :access_logs,
              %i[company_id accessed_at id],
              order: { accessed_at: :desc, id: :desc },
              name: "index_access_logs_on_company_recent"

    add_index :access_logs,
              %i[user_id accessed_at id],
              order: { accessed_at: :desc, id: :desc },
              name: "index_access_logs_on_user_recent"

    add_index :access_logs,
              %i[document_id accessed_at id],
              order: { accessed_at: :desc, id: :desc },
              name: "index_access_logs_on_document_recent"
  end
end
