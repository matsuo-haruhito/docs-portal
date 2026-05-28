require "rails_helper"

RSpec.describe "Admin document sets", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Delivery Project") }
  let(:empty_project) { create(:project, name: "Empty Project") }
  let(:document_a) { create(:document, project:, title: "概要仕様", slug: "overview") }
  let(:document_b) { create(:document, project:, title: "社内メモ", slug: "internal-memo") }
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

  def document_set_select_names
    parsed_html.css('select[name^="document_set["]').map { |node| node["name"] }
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map do |node|
      node["href"] || node["action"]
    end
  end

  def listed_document_set_names
    parsed_html.css('tbody td[data-rails-table-preferences-column-key="name"]').map do |node|
      node.text.squish
    end
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

    expect(response).to have_http_status(:unprocessable_entity)
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
    expect(page_text).not_to include("ほかの import 経路を確認してから戻ってください。")

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

    expect(response).to have_http_status(:unprocessable_entity)
    expect(page_text).to include("まだ対象文書がありません。")
    expect(page_text).to include("この案件の文書が取り込まれると、ここで対象文書を選べます。")
    expect(page_text).to include("ほかの import 経路を確認してから戻ってください。")
    expect(action_targets).to include(admin_git_import_sources_path, admin_git_import_runs_path)
    expect(page_text).not_to include("案件を選ぶと対象文書を設定できます。")
  end

  it "filters document sets by set_type and visibility_policy" do
    sign_in_as(admin)

    get admin_document_sets_path, params: { set_type: "delivery" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["既存セット", "配送社内セット"])

    get admin_document_sets_path, params: { visibility_policy: "internal_only" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["配送社内セット"])

    get admin_document_sets_path, params: { set_type: "delivery", visibility_policy: "restricted_external" }

    expect(response).to have_http_status(:ok)
    expect(listed_document_set_names).to eq(["既存セット"])
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

    expect(response).to have_http_status(:unprocessable_entity)
    expect(listed_document_set_names).to eq(["配送社内セット"])
    expect(document_set_form_action).to eq(admin_document_sets_path(set_type: "delivery", visibility_policy: "internal_only"))
  end

  it "renders rails_table_preferences editor and stable column keys on the index page" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書セット一覧の表示設定")

    editor = parsed_html.at_css(".rails-table-preferences-editor[data-controller='rails-table-preferences']")

    expect(editor).to be_present
    expect(editor["data-rails-table-preferences-table-key-value"]).to eq("admin_document_sets")
    expect(editor["data-rails-table-preferences-collection-url-value"]).to end_with("/rails_table_preferences/preferences/admin_document_sets")
    expect(editor["data-rails-table-preferences-url-value"]).to end_with("/rails_table_preferences/preferences/admin_document_sets/default")

    header_keys = parsed_html.css("thead th[data-rails-table-preferences-column-key]").map do |node|
      node["data-rails-table-preferences-column-key"]
    end

    expect(header_keys).to eq(%w[project name set_type visibility_policy documents_count actions])
  end

  it "renders edit and delete actions with public_id based paths" do
    sign_in_as(admin)

    get admin_document_sets_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(edit_admin_document_set_path(existing_document_set))
    expect(response.body).to include(admin_document_set_path(existing_document_set))
  end

  it "persists document set table preferences through the mounted engine api" do
    sign_in_as(admin)

    post "/rails_table_preferences/preferences/admin_document_sets", params: {
      settings: {
        columns: [
          {
            key: "project",
            visible: true,
            order: 10,
            width: 220,
            pinned: true
          },
          {
            key: "documents_count",
            visible: false,
            order: 50,
            width: 96
          }
        ]
      }
    }

    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body)).to include(
      "table_key" => "admin_document_sets",
      "name" => "default",
      "scope_type" => "owner",
      "editable" => true
    )

    preference = RailsTablePreferences::Preference.find_for(user: admin, table_key: "admin_document_sets")

    expect(preference).to be_present
    expect(preference.settings.fetch("columns")).to include(
      a_hash_including(
        "key" => "project",
        "visible" => true,
        "order" => 10,
        "width" => 220,
        "pinned" => true
      ),
      a_hash_including(
        "key" => "documents_count",
        "visible" => false,
        "order" => 50,
        "width" => 96,
        "pinned" => false
      )
    )
  end

  it "creates a document set with ordered items and a fixed version" do
    sign_in_as(admin)

    expect do
      post admin_document_sets_path, params: {
        document_set: {
          project_id: project.id,
          name: "初回提出セット",
          description: "first delivery",
          set_type: "delivery",
          visibility_policy: "restricted_external",
          sort_order: 3
        },
        document_set_items: {
          "0" => {
            selected: "1",
            document_id: document_a.id,
            document_version_id: version_a1.id,
            sort_order: 2,
            note: "固定版"
          },
          "1" => {
            selected: "1",
            document_id: document_b.id,
            document_version_id: "",
            sort_order: 5,
            note: ""
          }
        }
      }
    end.to change(DocumentSet, :count).by(1)

    expect(response).to redirect_to(admin_document_sets_path)

    document_set = DocumentSet.order(:id).last
    expect(document_set.document_set_items.ordered.map(&:document)).to eq([document_a, document_b])
    expect(document_set.document_set_items.ordered.first.document_version).to eq(version_a1)
    expect(document_set.document_set_items.ordered.second.document_version).to be_nil
  end

  it "resolves edit, update, and destroy through public_id" do
    sign_in_as(admin)

    get edit_admin_document_set_path(existing_document_set)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("対象文書")
    expect(response.body).to include(document_a.title)
    expect(parsed_html.at_css(%(form[action="#{admin_document_set_path(existing_document_set)}"]))).to be_present

    patch admin_document_set_path(existing_document_set), params: {
      document_set: {
        project_id: project.id,
        name: "更新後セット",
        description: existing_document_set.description,
        set_type: existing_document_set.set_type,
        visibility_policy: existing_document_set.visibility_policy,
        sort_order: existing_document_set.sort_order
      },
      document_set_items: {}
    }

    expect(response).to redirect_to(admin_document_sets_path)
    expect(existing_document_set.reload.name).to eq("更新後セット")

    expect do
      delete admin_document_set_path(existing_document_set)
    end.to change(DocumentSet, :count).by(-1)

    expect(response).to redirect_to(admin_document_sets_path)
  end

  it "does not resolve edit by numeric id once admin routes use public_id" do
    sign_in_as(admin)

    get "/admin/document_sets/#{existing_document_set.id}/edit"

    expect(response).to have_http_status(:not_found)
  end
end
