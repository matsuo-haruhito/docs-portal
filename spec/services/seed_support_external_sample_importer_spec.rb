require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/master_data_importer")

RSpec.describe SeedSupport::MasterDataImporter do
  let(:root) { Rails.root.join("tmp", "external-sample-seed-smoke-#{SecureRandom.hex(4)}") }
  let(:importer) { described_class.new }

  before do
    create(:company, domain: "example.com", name: "Example")
    create(:company, domain: "client-a.example.com", name: "Client A")
    create(:company, domain: "client-b.example.com", name: "Client B")
    create(:user, :admin, email_address: "admin@example.com", company: Company.find_by!(domain: "example.com"))

    site_root = root.join("representative-set", "product-handbook")
    FileUtils.mkdir_p(site_root.join("assets"))
    FileUtils.mkdir_p(site_root.join("提出済"))

    File.write(site_root.join("README.md"), <<~MARKDOWN)
      ---
      title: Portal Demo Home
      ---
      # Portal Demo Home
    MARKDOWN
    File.write(site_root.join("guide.md"), <<~MARKDOWN)
      ---
      title: Current Guide
      ---
      # Current Guide

      ![Guide diagram](assets/guide.png)
    MARKDOWN
    File.write(site_root.join("assets", "guide.png"), "image")
    File.write(site_root.join("提出済", "README.md"), <<~MARKDOWN)
      ---
      title: Submitted Home
      ---
      # Submitted Home
    MARKDOWN

    allow(importer).to receive(:sample_source_root).and_return(root)
    allow(SeedSupport::DocusaurusBuilder).to receive(:new).and_return(instance_double(SeedSupport::DocusaurusBuilder, build: {}))
  end

  after do
    FileUtils.rm_rf(root)
  end

  it "imports a representative external sample set into project, document, version, and file records" do
    importer.send(:seed_external_samples)

    project = Project.find_by!(name: "representative-set / product-handbook")
    home_document = project.documents.find_by!(title: "Portal Demo Home")
    guide_document = project.documents.find_by!(title: "Current Guide")

    expect(project.description).to eq("external_samples/representative-set 配下のサンプル文書サイト")
    expect(project.code).to start_with("EXT_REPRESENTATI_")
    expect(home_document.document_versions.pluck(:version_label)).to contain_exactly("current", "提出済")
    expect(home_document.latest_version.version_label).to eq("current")

    current_home_version = home_document.document_versions.find_by!(version_label: "current")
    submitted_home_version = home_document.document_versions.find_by!(version_label: "提出済")
    guide_version = guide_document.document_versions.find_by!(version_label: "current")

    expect(current_home_version.markdown_entry_path).to end_with("/current")
    expect(submitted_home_version.markdown_entry_path).to end_with("/ti-chu-ji")
    expect(guide_version.markdown_entry_path).to end_with("/current/guide")
    expect(guide_version.source_relative_path).to eq("guide.md")

    expect(current_home_version.document_files.pluck(:file_name)).to contain_exactly("README.md")
    expect(guide_version.document_files.order(:sort_order).pluck(:file_name)).to eq(["guide.md", "assets/guide.png"])
    expect(guide_version.document_files.find_by!(file_name: "assets/guide.png").content_type).to eq("image/png")

    external_company_ids = Company.where(domain: ["client-a.example.com", "client-b.example.com"]).pluck(:id)
    expect(home_document.document_permissions.where(company_id: external_company_ids).pluck(:access_level)).to contain_exactly("download", "download")
  end
end
