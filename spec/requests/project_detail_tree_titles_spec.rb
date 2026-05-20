require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Project detail tree titles", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DETAILTREE", name: "Detail Tree Project") }
  let(:document) { create(:document, project:, title: "設計書タイトル", slug: "design-title") }

  after do
    FileUtils.rm_rf(DocumentFile.storage_root.join("spec/project-detail-tree-titles"))
  end

  it "shows document titles rather than primary file names on the project detail tree" do
    version = create(:document_version, document:, version_label: "v1.0.0", status: :published)
    document.update!(latest_version: version)
    create_document_file!(version, file_name: "design.pdf")

    sign_in_as(user)

    get project_path(project)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("設計書タイトル")
    expect(response.body).not_to include('project-document-detail-tree__document-title" href="/projects/DETAILTREE/documents/design-title">design.pdf')
  end

  private

  def create_document_file!(version, file_name:)
    storage_key = "spec/project-detail-tree-titles/#{SecureRandom.hex(8)}/#{file_name}"
    absolute_path = DocumentFile.storage_root.join(storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    absolute_path.write("%PDF-1.4")

    version.document_files.create!(
      file_name:,
      content_type: "application/pdf",
      storage_key:,
      file_size: absolute_path.size,
      sort_order: 0,
      scan_status: :scan_clean
    )
  end
end
