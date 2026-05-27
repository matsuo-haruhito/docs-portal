require "rails_helper"

RSpec.describe "Admin documents", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def document_rows
    parsed_html.css("table tbody tr")
  end

  def row_column_texts(column_key)
    document_rows.map do |row|
      cell = row.at_css(%(td[data-rails-table-preferences-column-key="#{column_key}"]))
      next unless cell

      cell.xpath(".//text()").map { |node| node.text.squish }.reject(&:empty?).join(" ")
    end
  end

  it "uses public_id-based admin action links while keeping the public document link on the index" do
    active_document = create(:document, title: "Active Document")
    archived_document = create(:document, title: "Archived Document")
    archived_document.archive!(actor: admin_user)

    sign_in_as(admin_user)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(project_document_path(active_document.project, active_document.slug))
    expect(response.body).to include(edit_admin_document_path(active_document.public_id))
    expect(response.body).to include(archive_admin_document_path(active_document.public_id))
    expect(response.body).to include(admin_document_path(active_document.public_id))
    expect(response.body).to include(edit_admin_document_path(archived_document.public_id))
    expect(response.body).to include(restore_admin_document_path(archived_document.public_id))
    expect(response.body).to include(admin_document_path(archived_document.public_id))
    expect(response.body).not_to include(edit_admin_document_path(active_document.id))
    expect(response.body).not_to include(archive_admin_document_path(active_document.id))
    expect(response.body).not_to include(admin_document_path(active_document.id))
    expect(response.body).not_to include(edit_admin_document_path(active_document.slug))
    expect(response.body).not_to include(archive_admin_document_path(active_document.slug))
    expect(response.body).not_to include(admin_document_path(active_document.slug))
  end

  it "shows project codes in the project column so keyword search results stay easy to verify" do
    matching_project = create(:project, code: "DOCS-001", name: "Operations Portal")
    similar_project = create(:project, code: "DOCS-002", name: "Operations Portal")
    matching_document = create(:document, project: matching_project, title: "Operations Handbook", slug: "operations-handbook")
    other_document = create(:document, project: similar_project, title: "Operations Runbook", slug: "operations-runbook")

    sign_in_as(admin_user)

    get admin_documents_path, params: { q: "DOCS-001" }

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(project_document_path(matching_project, matching_document.slug))
    expect(response.body).not_to include(project_document_path(similar_project, other_document.slug))
    expect(row_column_texts("project")).to eq(["Operations Portal DOCS-001"])
  end

  it "finds the edit page by public_id and rejects numeric ids and slugs" do
    document = create(:document)

    sign_in_as(admin_user)

    get edit_admin_document_path(document.public_id)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("文書マスタ編集")

    get edit_admin_document_path(document.id)
    expect(response).to have_http_status(:not_found)

    get edit_admin_document_path(document.slug)
    expect(response).to have_http_status(:not_found)
  end

  it "updates a document via public_id and rejects numeric ids and slugs" do
    document = create(:document, title: "Original Title")

    sign_in_as(admin_user)

    patch admin_document_path(document.public_id), params: {
      document: {
        project_id: document.project_id,
        title: "Updated Title",
        slug: document.slug,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy,
        retention_until: document.retention_until,
        discard_candidate_at: document.discard_candidate_at
      }
    }

    expect(response).to redirect_to(admin_documents_path)
    expect(document.reload.title).to eq("Updated Title")

    patch admin_document_path(document.id), params: {
      document: {
        project_id: document.project_id,
        title: "Numeric Id Update",
        slug: document.slug,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy
      }
    }

    expect(response).to have_http_status(:not_found)
    expect(document.reload.title).to eq("Updated Title")

    patch admin_document_path(document.slug), params: {
      document: {
        project_id: document.project_id,
        title: "Slug Update",
        slug: document.slug,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy
      }
    }

    expect(response).to have_http_status(:not_found)
    expect(document.reload.title).to eq("Updated Title")
  end

  it "archives and restores a document via public_id while rejecting numeric ids and slugs" do
    document = create(:document)

    sign_in_as(admin_user)

    patch archive_admin_document_path(document.public_id)
    expect(response).to redirect_to(admin_documents_path)
    expect(document.reload).to be_archived

    patch restore_admin_document_path(document.id)
    expect(response).to have_http_status(:not_found)
    expect(document.reload).to be_archived

    patch restore_admin_document_path(document.slug)
    expect(response).to have_http_status(:not_found)
    expect(document.reload).to be_archived

    patch restore_admin_document_path(document.public_id)
    expect(response).to redirect_to(admin_documents_path)
    expect(document.reload).not_to be_archived

    patch archive_admin_document_path(document.id)
    expect(response).to have_http_status(:not_found)
    expect(document.reload).not_to be_archived

    patch archive_admin_document_path(document.slug)
    expect(response).to have_http_status(:not_found)
    expect(document.reload).not_to be_archived
  end

  it "destroys a document via public_id and rejects numeric ids and slugs" do
    deletable_document = create(:document)
    numeric_document = create(:document)
    slug_document = create(:document)

    sign_in_as(admin_user)

    delete admin_document_path(deletable_document.public_id)
    expect(response).to redirect_to(admin_documents_path)
    expect(Document.exists?(deletable_document.id)).to be(false)

    delete admin_document_path(numeric_document.id)
    expect(response).to have_http_status(:not_found)
    expect(Document.exists?(numeric_document.id)).to be(true)

    delete admin_document_path(slug_document.slug)
    expect(response).to have_http_status(:not_found)
    expect(Document.exists?(slug_document.id)).to be(true)
  end
end
