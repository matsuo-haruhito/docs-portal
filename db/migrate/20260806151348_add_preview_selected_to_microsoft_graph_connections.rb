class AddPreviewSelectedToMicrosoftGraphConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :microsoft_graph_connections, :preview_selected, :boolean, default: false, null: false, comment: "プレビュー利用に明示選択された接続"
  end
end
