require "rails_helper"

RSpec.describe "accessible_documents/index source" do
  let(:view_source) { Rails.root.join("app/views/accessible_documents/index.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/accessible_documents_helper.rb").read }

  it "uses rails_table_preferences for the result table only" do
    expect(view_source).to include("table_key = :accessible_documents")
    expect(view_source).to include("table_columns = accessible_document_table_columns(keyword_search: @filters[:q].present?)")
    expect(view_source).to include("rails_table_preference_settings(table_key: table_key)")
    expect(view_source).to include("render ColumnSettingsComponent.new(")
    expect(view_source).to include("table_preferences_table_tag(table_key: table_key, settings: table_settings, columns: table_columns, scroll_wrapper: true")
    expect(view_source).to include('wrapper_options: { class: "table-scroll", role: "region", tabindex: 0, aria: { label: "閲覧可能文書の検索結果" } }')
    expect(view_source).not_to include("table_preferences_editor(")
    expect(view_source).not_to include(".table-scroll tabindex=")
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

  it "keeps frequent and advanced filters in one native disclosure form" do
    expect(view_source).to include("details.filter-details open=advanced_filters_active")
    expect(view_source).to include("| 追加条件")
    expect(view_source).to include("advanced_enum_filters_active =")
    expect(view_source).to include("advanced_boolean_filters_active =")

    frequent_filter_position = view_source.index("form.rfk_select :tag")
    disclosure_position = view_source.index("details.filter-details")
    advanced_filter_position = view_source.index("form.rfk_select :category")

    expect(frequent_filter_position).to be < disclosure_position
    expect(advanced_filter_position).to be > disclosure_position
    expect(view_source.index("form.rfk_combobox :project_id")).to be < disclosure_position
    expect(view_source.index("check_box_tag :has_diagram")).to be > disclosure_position
  end

  it "uses keyword-aware defaults and keeps list controls together" do
    expect(helper_source).to include("def accessible_document_table_columns(keyword_search: false)")
    expect(helper_source).to include('table_preferences_column(:match_reason, label: "ヒット理由", default_visible: keyword_search, overflow: :ellipsis)')
    expect(helper_source).to include('table_preferences_column(:updated_at, label: "最終更新", default_visible: true, default_width: 130, overflow: :ellipsis)')
    expect(view_source).to include(".list-meta")
    expect(view_source).to include(".list-meta__tools")
    expect(view_source).to include("nav.pagination.list-meta__pagination")
    expect(view_source.index(".list-meta")).to be < view_source.index("table_preferences_table_tag")
    expect(view_source.index("nav.pagination.list-meta__pagination")).to be < view_source.index("render ColumnSettingsComponent.new")
    expect(view_source).to include('document.updated_at.strftime("%m/%d %H:%M")')
  end

  it "keeps filters, pagination, and match summary contracts" do
    expect(view_source).to include("form_with url: documents_path, method: :get")
    expect(view_source).to include("pagination_params = @filters.to_h.symbolize_keys.except(:page).compact_blank")
    expect(view_source).to include("documents_path(pagination_params.merge(page: @current_page + 1))")
    expect(view_source).to include("document_search_match_summaries(document, @filters[:q])")
  end
end
