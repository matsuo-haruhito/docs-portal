require "rails_helper"

RSpec.describe "Admin document return_to", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def action_cell_for(title)
    parsed_html.css("table tbody tr").find do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="title"] a))&.text&.squish == title
    end&.at_css(%(td[data-rails-table-preferences-column-key="actions"]))
  end

  def action_link_for(title, label)
    action_cell_for(title)&.css("a[href]")&.find { |node| node.text.squish == label }
  end

  def action_form_for(title, path)
    action_cell_for(title)&.css("form[action]")&.find do |node|
      URI.parse(node["action"]).path == path
    end
  end

  def query_params(url)
    Rack::Utils.parse_nested_query(URI.parse(url).query)
  end

  def hidden_field_value(name)
    parsed_html.at_css(%(input[name="#{name}"]))&.[]("value")
  end

  def document_update_params(document, title: document.title)
    {
      document: {
        project_id: document.project_id,
        title: title,
        slug: document.slug,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy,
        retention_until: document.retention_until,
        discard_candidate_at: document.discard_candidate_at
      }
    }
  end

  before do
    sign_in_as(admin_user)
  end

  it "passes filtered index context to edit and lifecycle actions" do
    project = create(:project, code: "RET-001", name: "Return Project")
    active_document = create(:document, project:, title: "Return Active", slug: "return-active")
    archived_document = create(:document, project:, title: "Return Archived", slug: "return-archived")
    archived_document.archive!(actor: admin_user)
    return_to = admin_documents_path(q: "RET-001", retention: "missing")

    get admin_documents_path, params: { q: "RET-001", retention: "missing" }

    expect(response).to have_http_status(:ok)
    expect(query_params(action_link_for("Return Active", "編集")["href"]).fetch("return_to")).to eq(return_to)
    expect(query_params(action_form_for("Return Active", archive_admin_document_path(active_document.public_id))["action"]).fetch("return_to")).to eq(return_to)
    expect(query_params(action_form_for("Return Active", admin_document_path(active_document.public_id))["action"]).fetch("return_to")).to eq(return_to)
    expect(query_params(action_link_for("Return Archived", "編集")["href"]).fetch("return_to")).to eq(return_to)
    expect(query_params(action_form_for("Return Archived", restore_admin_document_path(archived_document.public_id))["action"]).fetch("return_to")).to eq(return_to)
  end

  it "uses safe return_to for edit form, update, and lifecycle redirects" do
    project = create(:project, code: "SAFE-001", name: "Safe Return")
    document = create(:document, project:, title: "Safe Return Document", slug: "safe-return-document")
    archived_document = create(:document, project:, title: "Safe Archived Document", slug: "safe-archived-document")
    archived_document.archive!(actor: admin_user)
    deletable_document = create(:document, project:, title: "Safe Delete Document", slug: "safe-delete-document")
    return_to = admin_documents_path(q: "SAFE-001", retention: "missing")

    get edit_admin_document_path(document.public_id), params: { return_to: return_to }

    expect(response).to have_http_status(:ok)
    expect(hidden_field_value("return_to")).to eq(return_to)
    expect(parsed_html.css("a").find { |node| node.text.squish == "一覧へ戻る" }["href"]).to eq(return_to)

    patch admin_document_path(document.public_id), params: document_update_params(document, title: "Safe Return Updated").merge(return_to: return_to)
    expect(response).to redirect_to(return_to)

    patch archive_admin_document_path(document.public_id), params: { return_to: return_to }
    expect(response).to redirect_to(return_to)
    expect(document.reload).to be_archived

    patch restore_admin_document_path(archived_document.public_id), params: { return_to: return_to }
    expect(response).to redirect_to(return_to)
    expect(archived_document.reload).not_to be_archived

    delete admin_document_path(deletable_document.public_id), params: { return_to: return_to }
    expect(response).to redirect_to(return_to)
    expect(Document.exists?(deletable_document.id)).to be(false)
  end

  it "falls back to the document index for unsafe return_to values" do
    unsafe_return_to_values = [
      nil,
      "",
      "//evil.example/admin/documents",
      "https://evil.example/admin/documents",
      "mailto:admin@example.com",
      "#documents",
      "/admin/documents\nX-Injected: yes"
    ]

    unsafe_return_to_values.each_with_index do |return_to, index|
      document = create(:document, title: "Unsafe Return #{index}", slug: "unsafe-return-#{index}")
      params = document_update_params(document, title: "Unsafe Return Updated #{index}")
      params[:return_to] = return_to unless return_to.nil?

      patch admin_document_path(document.public_id), params: params

      expect(response).to redirect_to(admin_documents_path)
    end
  end
end
