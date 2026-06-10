require "rails_helper"

RSpec.describe "markdown preview table fallback boundary" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:inventory_source) { read_source("doc/frontend_initialization_inventory.md") }
  let(:table_tools_source) { read_source("app/frontend/lib/markdown_preview_table_tools.js") }
  let(:table_resizer_source) { read_source("app/frontend/controllers/preview_table_resizer_controller.js") }

  it "documents the current fallback support without claiming full rails_table_preferences integration" do
    aggregate_failures do
      expect(inventory_source).to include("current fallback support として提供していること")
      expect(inventory_source).to include("iframe 内の Markdown table wrapping、横スクロール、列幅調整、ヘッダー固定、先頭列固定")
      expect(inventory_source).to include("table search、copy、CSV / Markdown export、表示設定の reset")
      expect(inventory_source).to include("既存の `/rails_table_preferences/preferences` path と `railsTablePreferencesTableKey` を使う default preference 補助")
      expect(inventory_source).to include("#475 に残すこと")
      expect(inventory_source).to include("column visibility / preset UI の本格統合")
      expect(inventory_source).to include("Docusaurus renderer や Markdown table DOM rewrite、preference schema / key の再設計")
      expect(inventory_source).to include("gem pinned ref、upstream gem API、Rails helper 側の table contract 変更")
      expect(inventory_source).to include("Markdown preview table の full `rails_table_preferences` 統合")
    end
  end

  it "keeps the fallback description aligned with the source-level helper surfaces" do
    aggregate_failures do
      expect(table_tools_source).to include('const TABLE_PREFERENCE_COLLECTION_PATH = "/rails_table_preferences/preferences"')
      expect(table_tools_source).to include("const tableKey = table.dataset.railsTablePreferencesTableKey")
      expect(table_tools_source).to include("function updateTableSearch(table, input, count)")
      expect(table_tools_source).to include("copyText(tableToCsv(table), copyStatus)")
      expect(table_tools_source).to include("copyText(tableToMarkdown(table), copyStatus)")
      expect(table_tools_source).to include("installPreferencePanel(frameDocument, table, displayGroup, copyStatus)")

      expect(table_resizer_source).to include("const TABLE_WIDTH_STORAGE_PREFIX")
      expect(table_resizer_source).to include("const TABLE_COLUMN_WIDTH_STORAGE_PREFIX")
      expect(table_resizer_source).to include("const TABLE_STICKY_HEADER_STORAGE_PREFIX")
      expect(table_resizer_source).to include("const TABLE_STICKY_COLUMN_STORAGE_PREFIX")
      expect(table_resizer_source).to include("function previewContextKey(frame)")
      expect(table_resizer_source).to include("function copyTablePreferenceMetadata(wrapper, table)")
      expect(table_resizer_source).to include("notifyTablesEnhanced(frame)")
    end
  end
end
