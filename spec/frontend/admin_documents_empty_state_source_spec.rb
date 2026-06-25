require "rails_helper"

RSpec.describe "admin documents empty state source" do
  let(:index_source) { Rails.root.join("app/views/admin/documents/index.html.slim").read }

  it "keeps zero-result next actions ahead of the table preference surface" do
    aggregate_failures do
      expect(index_source).to include("documents_empty = @documents_filtered_count.zero?")
      expect(index_source).to include(".card.document-list-empty-guidance")
      expect(index_source).to include("条件に一致する文書がないため、一覧の列設定と空テーブルは畳んでいます。")
      expect(index_source).to include("登録済みの文書がまだありません。上部の新規登録フォームから最初の文書を追加すると、一覧の表示設定と文書テーブルを確認できます。")
      expect(index_source).to include('= link_to "条件をクリア", admin_documents_path, class: "button secondary"')
    end
  end

  it "visually retreats empty table preference UI without changing its DOM contract" do
    aggregate_failures do
      expect(index_source).to include(".card hidden=(documents_empty ? true : nil)")
      expect(index_source).to include('table[data-rails-table-preferences-table-key-value="admin_documents"] { display: none; }')
      expect(index_source).to include('table_preferences_editor(table_key: table_key, settings: table_settings, columns: table_columns, title: "文書マスタ一覧の表示設定")')
      expect(index_source).to include("table_preferences_table_tag(table_key: table_key, settings: table_settings, columns: table_columns)")
    end
  end
end
