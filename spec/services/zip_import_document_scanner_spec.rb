require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe ZipImportDocumentScanner do
  let(:root) { Rails.root.join("tmp", "zip-import-document-scanner-#{SecureRandom.hex(4)}") }
  let(:scanner) { described_class.new(root:) }

  before do
    FileUtils.mkdir_p(root.join("guides"))
    FileUtils.mkdir_p(root.join("__MACOSX"))

    File.write(root.join("README.md"), <<~MARKDOWN)
      ---
      title: Root README
      ---
      # Overview

      ![Flow](guides/flow.png)
    MARKDOWN
    File.write(root.join("guides", "system.mmd"), "flowchart TD\n  A --> B\n")
    File.write(root.join("guides", "system.png"), "image")
    File.write(root.join("guides", "flow.png"), "image")
    File.write(root.join("guides", "notes.txt"), "orphan")
    File.write(root.join(".DS_Store"), "noise")
    File.write(root.join("__MACOSX", "._README.md"), "noise")
  end

  after do
    FileUtils.rm_rf(root)
  end

  it "detects markdown and standalone diagram files, and separates orphan and skipped files" do
    result = scanner.call

    expect(result.documents.map(&:logical_path)).to contain_exactly("README.md", "guides/system.mmd")
    expect(result.documents.find { _1.logical_path == "README.md" }.attachment_paths.map { scanner.send(:logical_path_for, _1) }).to include("README.md", "guides/flow.png")
    expect(result.documents.find { _1.logical_path == "guides/system.mmd" }.attachment_paths.map { scanner.send(:logical_path_for, _1) }).to contain_exactly("guides/system.mmd", "guides/system.png")
    expect(result.orphan_files).to contain_exactly("guides/notes.txt")
    expect(result.skipped_files).to contain_exactly(".DS_Store", "__MACOSX/._README.md")
  end
end
