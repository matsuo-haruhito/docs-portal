require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/external_sample_document_scanner")

RSpec.describe SeedSupport::ExternalSampleDocumentScanner do
  let(:root) { Rails.root.join("tmp", "external-sample-scanner-#{SecureRandom.hex(4)}") }
  let(:scanner) { described_class.new(root:) }

  before do
    FileUtils.mkdir_p(root.join("docs", "flows"))
    File.write(root.join("docs", "README.md"), "# README\n")
    File.write(root.join("docs", "flows", "shipping.mmd"), "flowchart TD\n  A --> B\n")
    File.write(root.join("docs", "flows", "shipping.png"), "image")
    File.write(root.join("docs", "ignore.png"), "image")
  end

  after do
    FileUtils.rm_rf(root)
  end

  it "detects markdown and standalone diagram files as document candidates" do
    files = scanner.document_files_for(root.join("docs")).map { Pathname(_1).relative_path_from(root.join("docs")).to_s }

    expect(files).to contain_exactly("README.md", "flows/shipping.mmd")
  end

  it "keeps a standalone diagram file itself as an attachment candidate" do
    attachments = scanner.related_attachment_files(
      root.join("docs", "flows", "shipping.mmd"),
      "flows/shipping.mmd",
      root.join("docs")
    ).map { Pathname(_1).relative_path_from(root.join("docs")).to_s }

    expect(attachments).to contain_exactly("flows/shipping.mmd", "flows/shipping.png")
  end

  it "returns text/plain for standalone diagram files" do
    expect(scanner.content_type_for(root.join("docs", "flows", "shipping.mmd"))).to eq("text/plain")
  end
end
