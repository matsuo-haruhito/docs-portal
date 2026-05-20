require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe "Document terminal history status", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "TERMSTAT", name: "Terminal Status Project") }
  let(:document) { create(:document, project:, title: "Terminal Status Guide", slug: "current-guide") }

  after do
    FileUtils.rm_rf(Rails.root.join("storage", "document_files", "spec", "terminal-history-status"))
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
      File.write(index_path, "<html></html>")
    end
  end

  def create_metadata_file(version, content)
    storage_key = "spec/terminal-history-status/#{SecureRandom.hex(8)}/.docs-portal-history.yml"
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

  it "shows archived notice for archived site path metadata" do
    version = create_site_version
    create_metadata_file(version, <<~YAML)
      path_history:
        archived:
          - site_path: docs/archived-guide
            reason: old publication
    YAML

    sign_in_as(user)

    get project_document_path(project, document.slug, version_id: version.public_id, site_path: "docs/archived-guide")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("アーカイブ済み")
    expect(response.body).to include("このURLに対応する文書はアーカイブ済みです")
    expect(response.body).to include("docs/archived-guide -&gt; docs/current-guide")
  end

  it "shows deleted notice for deleted slug metadata" do
    version = create_site_version
    create_metadata_file(version, <<~YAML)
      path_history:
        deleted:
          - slug: deleted-guide
            reason: removed from scope
    YAML

    sign_in_as(user)

    get project_document_path(project, "deleted-guide")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("削除済み")
    expect(response.body).to include("このURLに対応する文書は削除済みです")
    expect(response.body).to include("deleted-guide -&gt; current-guide")
  end
end
