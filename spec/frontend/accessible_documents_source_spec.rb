require "rails_helper"

RSpec.describe "accessible_documents/index source" do
  let(:view_source) { Rails.root.join("app/views/accessible_documents/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/accessible_documents_helper.rb").read }

  it "uses rails_table_preferences for the result table only" do
    expect(view_source).to include("table_key = :accessible_documents")
    expect(view_source).to include("table_columns = accessible_document_table_columns")
    expect(view_source).to include("rails_table_preference_settings(table_key: table_key)")
    expect(view_source).to include("table_preferences_editor(table_key: table_key, settings: table_settings, columns: table_columns, title: \"閲覧可能文書一覧の表示設定\")")
    expect(view_source).to include("table_preferences_table_tag(table_key: table_key, settings: table_settings, columns: table_columns)")
  end

  it "keeps the keyword placeholder short and moves searchable targets into visible help" do
    expect(view_source).to include('placeholder: "文書名・案件名など"')
    expect(view_source).to include("span.muted\n          | 文書名・案件名・本文・タグ・添付ファイル名・元パスの短い語句で検索できます。")
    expect(view_source).not_to include("p.muted\n          | 本文、キーワード、タグ、添付ファイル名、元パスでも検索できます。")
    expect(view_source).not_to include('placeholder: "案件名・文書名・URL識別子・元パス・版・本文・キーワード・添付ファイル名/パス"')
  end

  it "keeps stable column keys on headers and cells" do
    %w[
      project document match_reason tags category document_kind importance_level visibility_policy latest_version html files updated_at
    ].each do |column_key|
      expect(view_source.scan(%(data-rails-table-preferences-column-key="#{column_key}")).size).to eq(2)
    end
  end

  it "defines matching column metadata without changing filters or pagination" do
    expect(helper_source).to include("table_preferences_column(:project, label: \"案件\", default_width: 180, pinned: true, overflow: :ellipsis)")
    expect(helper_source).to include("table_preferences_column(:document, label: \"文書名\", default_width: 240, pinned: true, overflow: :ellipsis)")
    expect(helper_source).to include("table_preferences_column(:match_reason, label: \"ヒット理由\", default_width: 240, overflow: :ellipsis)")
    expect(helper_source).to include("table_preferences_column(:tags, label: \"タグ\", default_width: 220, overflow: :ellipsis)")
    expect(helper_source).to include("table_preferences_column(:updated_at, label: \"最終更新\", default_width: 160, sortable: true)")
    expect(view_source).to include("form_with url: documents_path, method: :get")
    expect(view_source).to include("pagination_params = @filters.to_h.symbolize_keys.except(:page).compact_blank")
    expect(view_source).to include("documents_path(pagination_params.merge(page: @current_page + 1))")
    expect(view_source).to include("document_search_match_summaries(document, @filters[:q])")
  end
end
