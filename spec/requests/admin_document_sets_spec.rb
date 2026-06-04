require "rails_helper"

RSpec.describe "Admin document sets", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Delivery Project") }
  let(:empty_project) { create(:project, name: "Empty Project") }
  let(:document_a) { create(:document, project:, title: "概要仕様", slug: "overview") }
  let!(:document_b) { create(:document, project:, title: "社内メモ", slug: "internal-memo") }
  let!(:version_a1) { create(:document_version, document: document_a, version_label: "v1.0.0") }
  let!(:version_a2) { create(:document_version, document: document_a, version_label: "v2.0.0") }
  let!(:existing_document_set) do
    create(
      :document_set,
      project:,
      name: "既存セット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 1
    )
  end
  let!(:delivery_internal_set) do
    create(
      :document_set,
      project:,
      name: "配送社内セット",
      set_type: :delivery,
      visibility_policy: :internal_only,
      sort_order: 2
    )
  end
  let!(:design_public_set) do
    create(
      :document_set,
      project:,
      name: "設計公開セット",
      set_type: :design,
      visibility_policy: :public_with_login,
      sort_order: 3
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def json_body
    JSON.parse(response.body)
  end

  def document_set_select_names
    parsed_html.css('select[name^="document_set["]').map { |node| node["name"] }
  end

  def document_set_filter_select_names
    parsed_html.css("form.document-set-filter-form select").map { |node| node["name"] }
  end

  def document_set_filter_options(name)
    parsed_html.css(%(form.document-set-filter-form select[name="#{name}"] option)).map do |node|
      [node.text.squish, node["value"]]
    end
  end

  def clear_filter_targets
    parsed_html.css('a[href]').select { |node| node.text.squish == "条件をクリア" }.map { |node| node["href"] }
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def empty_project_import_targets
    parsed_html.css(".document-set-empty-import-links a[href]").map { |node| node["href"] }
  end

  def listed_document_set_names
    parsed_html.css('tbody td[data-rails-table-preferences-column-key="name"]').map do |node|
      node.text.squish
    end
  end

  def document_set_rows
    parsed_html.css("table tbody tr")
  end

  def document_set_row_for(document)
    parsed_html.at_css(%(tr[data-document-set-document-filter-document-id="#{document.id}"]))
  end

  def remote_document_picker
    parsed_html.at_css('select[name="document_set_remote_document_id"]')
  end

  def table_preference_surfaces
    parsed_html.css(%([data-rails-table-preferences-table-key-value="admin_document_sets"]))
  end

  def table_preference_settings_for(surface)
    JSON.parse(surface["data-rails-table-preferences-settings-value"])
  end

  def table_preference_columns_for(surface)
    JSON.parse(surface["data-rails-table-preferences-columns-value"])
  end

  def table_preference_table
    parsed_html.at_css(%(table[data-rails-table-preferences-table-key-value="admin_document_sets"]))
  end

  def document_set_form_action
    parsed_html.css("form[action]").find do |node|
      node.at_css('input[name="document_set[name]"]')
    end&.[]("action")
  end

  it "renders the document set select fields on initial load and invalid rerender" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(document_set_select_names).to include(
      "document_set[project_id]",
      "document_set[set_type]",
      "document_set[visibility_policy]"
    )

    post admin_document_sets_path, params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "first delivery",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 3
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(document_set_select_names).to include(
      "document_set[project_id]",
      "document_set[set_type]",
      "document_set[visibility_policy]"
    )
  end

  it "shows different guidance for an unselected project and a selected project without documents" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選ぶと対象文書を設定できます。")
    expect(page_text).not_to include("まだ対象文書がありません。")
    expect(empty_project_import_targets).to be_empty

    post admin_document_sets_path, params: {
      document_set: {
        project_id: empty_project.id,
        name: "",
        description: "empty project setup",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 0
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("まだ対象文書がありません。")
    expect(page_text).to include("この案件に文書を取り込むと、ここで対象文書を選べます。")
    expect(empty_project_import_targets).to include(
      admin_git_import_sources_path,
      admin_git_import_runs_path,
      new_admin_zip_import_path
    )
    expect(page_text).not_to include("案件を選ぶと対象文書を設定できます。")
  end

  it "renders the RFK remote document picker without changing selected row inputs" do
    sign_in_as(admin)

    post admin_document_sets_path, params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "remote picker render",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 0
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("文書名 / URL識別子で探す")
    expect(page_text).to include("表示中の対象文書を絞り込み")

    picker = remote_document_picker
    expect(picker).to be_present
    expect(picker["data-controller"]).to include("rails-fields-kit--tom-select")
    expect(picker["data-rails-fields-kit--tom-select-kind-value"]).to eq("combobox")
    expect(picker["data-rails-fields-kit--tom-select-url-value"]).to eq(document_search_admin_document_sets_path(project_id: project.id))
    expect(picker["data-rails-fields-kit--tom-select-query-param-value"]).to eq("q")
    expect(picker["data-rails-fields-kit--tom-select-value-field-value"]).to eq("id")
    expect(picker["data-rails-fields-kit--tom-select-label-field-value"]).to eq("title")
    expect(picker["data-rails-fields-kit--tom-select-option-description-field-value"]).to eq("slug")
    expect(picker["data-rails-fields-kit--tom-select-min-length-value"]).to eq("1")
    expect(picker["data-rails-fields-kit--tom-select-max-options-value"]).to eq("20")
    expect(picker["data-action"]).to include("rails-fields-kit--tom-select:change->document-set-document-filter#pickRemoteDocument")

    row = document_set_row_for(document_a)
    expect(row).to be_present
    expect(row["data-document-set-document-filter-slug"]).to eq("overview")
    expect(row.at_css(%(input[name^="document_set_items"][value="#{document_a.id}"]))).to be_present
  end

  it "renders and applies document set filters by set_type and visibility_policy" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(document_set_filter_select_names).to contain_exactly("set_type", "visibility_policy")
    expect(document_set_filter_options("set_type")).to include(["すべて", ""], ["送付用", "delivery"], ["設計", "design"])
    expect(document_set_filter_options("visibility_policy")).to include(["すべて", ""], ["限定公開", "restricted_external"], ["社内のみ", "internal_only"])
    expect(page_text).to include("表示設定は列の表示・幅を調整します")

    get admin_document_sets_path, params: { set_type: "delivery" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["既存セット", "配送社内セット"])
    expect(page_text).to include("種別: 送付用")
    expect(clear_filter_targets).to include(admin_document_sets_path)

    get admin_document_sets_path, params: { visibility_policy: "internal_only" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["配送社内セット"])
    expect(page_text).to include("公開範囲: 社内のみ")
    expect(clear_filter_targets).to include(admin_document_sets_path)

    get admin_document_sets_path, params: { set_type: "delivery", visibility_policy: "restricted_external" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["既存セット"])
    expect(page_text).to include("種別: 送付用")
    expect(page_text).to include("公開範囲: 限定公開")
  end

  it "restores saved table preference settings while keeping document set filters usable" do
    RailsTablePreferences::Preference.create!(
      user: admin,
      table_key: "admin_document_sets",
      name: "default",
      settings: {
        "columns" => [
          { "key" => "project", "visible" => true, "width" => 260, "order" => 1 },
          { "key" => "name", "visible" => true, "width" => 300, "order" => 2 },
          { "key" => "actions", "visible" => false, "width" => 140, "order" => 3 },
          { "key" => "not_a_document_set_column", "visible" => false }
        ],
        "filters" => {
          "set_type" => { "operator" => "eq", "value" => "delivery" },
          "not_a_document_set_column" => { "operator" => "contains", "value" => "Ignored" }
        },
        "sorts" => [
          { "key" => "name", "direction" => "asc" },
          { "key" => "not_a_document_set_column", "direction" => "desc" }
        ]
      }
    )

    sign_in_as(admin)

    get admin_document_sets_path, params: { set_type: "delivery" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 2件")
    expect(page_text).to include("種別: 送付用")
    expect(listed_document_set_names).to eq(["既存セット", "配送社内セット"])

    settings = table_preference_surfaces.map { |surface| table_preference_settings_for(surface) }
    expect(settings).to all(include(
      "columns" => contain_exactly(
        include("key" => "project", "visible" => true, "width" => 260, "order" => 1),
        include("key" => "name", "visible" => true, "width" => 300, "order" => 2),
        include("key" => "actions", "visible" => false, "width" => 140, "order" => 3)
      ),
      "filters" => { "set_type" => include("operator" => "eq", "value" => "delivery") },
      "sorts" => [include("key" => "name", "direction" => "asc")]
    ))
  end

  it "exposes stable table preference column metadata for the representative document set screen" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書セット一覧の表示設定")

    columns = table_preference_columns_for(table_preference_table)
    expect(columns.map { |column| column["key"] }).to eq(%w[project name set_type visibility_policy documents_count actions])
    expect(columns.select { |column| column["pinned"] }.map { |column| column["key"] }).to eq(%w[project actions])
    expect(columns.find { |column| column["key"] == "set_type" }).to include(
      "filter" => include("type" => "select", "param" => "set_type")
    )
    expect(columns.find { |column| column["key"] == "visibility_policy" }).to include(
      "filter" => include("type" => "select", "param" => "visibility_policy")
    )
  end

  it "keeps empty filtered results outside table preference surfaces" do
    sign_in_as(admin)

    get admin_document_sets_path, params: { set_type: "delivery", visibility_policy: "public_with_login" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 0件")
    expect(page_text).to include("種別: 送付用")
    expect(page_text).to include("公開範囲: ログインユーザー公開")
    expect(page_text).to include("条件に一致する文書セットはありません。")
    expect(clear_filter_targets).to include(admin_document_sets_path)
    expect(document_set_rows).to be_empty
    expect(table_preference_surfaces).to be_empty
  end

  it "returns project-scoped document search results by title and slug" do
    other_project = create(:project, name: "Other Project")
    create(:document, project: other_project, title: "概要仕様 外部", slug: "outside-overview")
    document_a.update!(latest_version: version_a2)

    sign_in_as(admin)

    get document_search_admin_document_sets_path, params: { project_id: project.id, q: "概要" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("documents")).to contain_exactly(
      a_hash_including(
        "id" => document_a.id,
        "title" => "概要仕様",
        "slug" => "overview",
        "text" => "概要仕様 (overview)",
        "latest_version_label" => "v2.0.0"
      )
    )
    expect(json_body.fetch("options")).to eq(json_body.fetch("documents"))

    get document_search_admin_document_sets_path, params: { project_id: project.id, q: "internal" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("documents")).to contain_exactly(
      a_hash_including("id" => document_b.id, "title" => "社内メモ", "slug" => "internal-memo", "text" => "社内メモ (internal-memo)")
    )
    expect(json_body.fetch("options")).to eq(json_body.fetch("documents"))
  end

  it "keeps document search empty for no-hit queries without leaking other projects" do
    other_project = create(:project, name: "Search Boundary Project")
    create(:document, project: other_project, title: "秘密仕様", slug: "secret-spec")

    sign_in_as(admin)

    get document_search_admin_document_sets_path, params: { project_id: project.id, q: "秘密" }

    expect(response).to have_http_status(:ok)
    expect(json_body.fetch("documents")).to eq([])
    expect(json_body.fetch("options")).to eq([])
  end

  it "keeps the current filter context on invalid create rerender" do
    sign_in_as(admin)

    post admin_document_sets_path(set_type: "delivery", visibility_policy: "internal_only"), params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "filtered create",
        set_type: "delivery",
        visibility_policy: "internal_only",
        sort_order: 4
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(listed_document_set_names).to eq(["配送社内セット"])
    expect(page_text).to include("種別: 送付用")
    expect(page_text).to include("公開範囲: 社内のみ")
    expect(document_set_form_action).to eq(admin_document_sets_path(set_type: "delivery", visibility_policy: "internal_only"))
  end

  it "keeps selected document rows and fixed versions on invalid create rerender" do
    sign_in_as(admin)

    post admin_document_sets_path, params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "selected row retention",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 4
      },
      document_set_items: {
        "0" => {
          selected: "1",
          document_id: document_a.id,
          document_version_id: version_a2.id,
          sort_order: "7",
          note: "keep me"
        }
      }
    }

    expect(response).to have_http_status(:unprocessable_content)

    row = document_set_row_for(document_a)
    expect(row).to be_present
    expect(row["class"]).to include("is-selected")
    expect(row.at_css('input[type="checkbox"][checked]')).to be_present
    expect(row.at_css(%(select option[value="#{version_a2.id}"][selected]))).to be_present
    expect(row.at_css('input[name$="[note]"]')["value"]).to eq("keep me")
    expect(remote_document_picker["data-rails-fields-kit--tom-select-url-value"]).to eq(document_search_admin_document_sets_path(project_id: project.id))
  end

  it "persists selected project documents while ignoring out-of-scope and unselected item rows" do
    other_project = create(:project, name: "Other Project")
    other_document = create(:document, project: other_project, title: "外部文書", slug: "external-doc")
    other_version = create(:document_version, document: other_document, version_label: "outside")

    sign_in_as(admin)

    expect do
      post admin_document_sets_path, params: {
        document_set: {
          project_id: project.id,
          name: "境界固定セット",
          description: "contract spec",
          set_type: "delivery",
          visibility_policy: "restricted_external",
          sort_order: 5
        },
        document_set_items: {
          "0" => {
            selected: "1",
            document_id: document_a.id,
            document_version_id: version_a2.id,
            sort_order: "7",
            note: "version pinned"
          },
          "1" => {
            selected: "1",
            document_id: document_b.id,
            document_version_id: version_a1.id,
            sort_order: "8",
            note: "mismatched version"
          },
          "2" => {
            selected: "1",
            document_id: other_document.id,
            document_version_id: other_version.id,
            sort_order: "9",
            note: "other project"
          },
          "3" => {
            selected: "0",
            document_id: document_a.id,
            document_version_id: version_a1.id,
            sort_order: "10",
            note: "not selected"
          },
          "4" => {
            selected: "1",
            document_id: "",
            document_version_id: "",
            sort_order: "11",
            note: "blank document"
          }
        }
      }
    end.to change(DocumentSet, :count).by(1).and change(DocumentSetItem, :count).by(2)

    expect(response).to redirect_to(admin_document_sets_path)

    document_set = DocumentSet.find_by!(name: "境界固定セット")
    items = document_set.document_set_items.includes(:document, :document_version).order(:sort_order)

    expect(items.map(&:document)).to eq([document_a, document_b])
    expect(items.first).to have_attributes(
      document_version: version_a2,
      sort_order: 7,
      note: "version pinned"
    )
    expect(items.second).to have_attributes(
      document_version: nil,
      sort_order: 8,
      note: "mismatched version"
    )
  end

  it "rebuilds existing document set items from selected in-project rows on update" do
    create(
      :document_set_item,
      document_set: existing_document_set,
      document: document_a,
      document_version: version_a1,
      sort_order: 1,
      note: "old item"
    )
    other_project = create(:project, name: "Update Other Project")
    other_document = create(:document, project: other_project, title: "更新外文書", slug: "update-external-doc")

    sign_in_as(admin)

    patch admin_document_set_path(existing_document_set), params: {
      document_set: {
        project_id: project.id,
        name: "既存セット更新",
        description: existing_document_set.description,
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 1
      },
      document_set_items: {
        "0" => {
          selected: "1",
          document_id: document_b.id,
          document_version_id: "",
          sort_order: "4",
          note: "replacement item"
        },
        "1" => {
          selected: "1",
          document_id: other_document.id,
          document_version_id: "",
          sort_order: "5",
          note: "other project ignored"
        },
        "2" => {
          selected: "0",
          document_id: document_a.id,
          document_version_id: version_a1.id,
          sort_order: "6",
          note: "unselected ignored"
        }
      }
    }

    expect(response).to redirect_to(admin_document_sets_path)

    items = existing_document_set.reload.document_set_items.includes(:document, :document_version)
    expect(items).to contain_exactly(
      have_attributes(
        document: document_b,
        document_version: nil,
        sort_order: 4,
        note: "replacement item"
      )
    )
  end

  it "renders rails_table_preferences editor and stable column keys on the index page" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書セット一覧の表示設定")
    expect(response.body).to include('data-rails-table-preferences-column-key="project"')
    expect(response.body).to include('data-rails-table-preferences-column-key="documents_count"')
  end
end
