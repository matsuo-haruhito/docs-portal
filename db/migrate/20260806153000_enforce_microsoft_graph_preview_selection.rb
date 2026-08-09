class EnforceMicrosoftGraphPreviewSelection < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      lock_target_table!
      validate_preview_selection!

      add_index :microsoft_graph_connections,
        :project_id,
        unique: true,
        where: "preview_selected = TRUE",
        name: "index_microsoft_graph_connections_on_preview_project"

      add_check_constraint :microsoft_graph_connections,
        "NOT preview_selected OR enabled",
        name: "microsoft_graph_preview_selection_requires_enabled",
        validate: false
      validate_check_constraint :microsoft_graph_connections,
        name: "microsoft_graph_preview_selection_requires_enabled"
    end
  end

  def down
    safety_assured do
      lock_target_table!
      remove_check_constraint :microsoft_graph_connections,
        name: "microsoft_graph_preview_selection_requires_enabled"
      remove_index :microsoft_graph_connections,
        name: "index_microsoft_graph_connections_on_preview_project"
    end
  end

  private

  def lock_target_table!
    execute "LOCK TABLE microsoft_graph_connections IN ACCESS EXCLUSIVE MODE"
  end

  def validate_preview_selection!
    duplicate_project_ids = connection.select_values(<<~SQL.squish)
      SELECT project_id
      FROM microsoft_graph_connections
      WHERE preview_selected = TRUE
      GROUP BY project_id
      HAVING COUNT(*) > 1
    SQL
    if duplicate_project_ids.any?
      raise "複数のpreview接続が選択されている案件があります: #{duplicate_project_ids.join(', ')}"
    end

    disabled_ids = connection.select_values(<<~SQL.squish)
      SELECT id
      FROM microsoft_graph_connections
      WHERE preview_selected = TRUE AND enabled = FALSE
    SQL
    return if disabled_ids.empty?

    raise "無効な接続がpreview用に選択されています: #{disabled_ids.join(', ')}"
  end
end
