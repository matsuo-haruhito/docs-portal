require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Project site embedded terminal history status", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "EMBTERM", name: "Embedded Terminal Project") }
  let(:document) { create(:document, project:, title: "Embedded Terminal Guide", slug: "current-guide") }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "embedded-terminal-history"))
    document.document_versions.find_each { |version| FileUtils.rm_rf(version.site_root_absolute_path) }
  end

  def create_site_version
    create(
      :document_version,
      document:,
      status: :published,
      markdown_entry_path: "docs/current-guide",
      site_build_path: "docs/current-guide"
    ).tap do |version|
      document.update!(latest_version: version)
      index_path = version.site_root_absolute_path.join("docs/current-guide", "index.html")
      FileUtils.mkdir_p(index_path.dirname)
      File.write(index_path, "<html><body>current</body></html>")
    end
  end

  def create_metadata_file(version, content)
    storage_key = "spec/embedded-terminal-history/#{SecureRandom.hex(8)}/.docs-portal-history.yml"
    absolute_path = Rails.root.join("storage", "document_files", storage_key)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, content)

    DocumentFile.create!(
      document_version: version,
      file_name: ".docs-portal-history.yml",
      content_type: "text/yaml",
      storage_key:,
      file_size: content.bytesize,
      sort_order: 0
    )
  end

  it "keeps embedded terminal paths renderable and exposes history headers" do
    version = create_site_version
    create_metadata_file(version, <<~YAML)
      path_history:
        archived:
          - site_path: docs/archived-guide
            reason: old publication
    YAML

    sign_in_as(user)

    get project_site_path(project, version_id: version.public_id, site_path: "docs/archived-guide", embedded: "1")

    expect(response).to have_http_status(:ok)
    expect(response.headers["X-Docs-Portal-History-Status"]).to eq("archived")
    expect(response.headers["X-Docs-Portal-History-Requested-Path"]).to eq("docs/archived-guide")
    expect(response.headers["X-Docs-Portal-History-Canonical-Path"]).to eq("docs/current-guide")
  end
end
