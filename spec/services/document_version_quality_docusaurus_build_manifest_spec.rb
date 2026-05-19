require "rails_helper"
require "fileutils"

RSpec.describe "DocumentVersionQuality Docusaurus build manifest" do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:, title: "Operation Manual") }
  let(:version) do
    create(
      :document_version,
      document:,
      source_commit_hash: "abc123",
      markdown_entry_path: "docs/manual",
      site_build_path: "docs/manual"
    )
  end

  after do
    FileUtils.rm_rf(version.site_root_absolute_path)
  end

  def write_site_file(relative_path:, content:)
    absolute_path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, content)
  end

  it "reports the manifest source as info" do
    write_site_file(relative_path: "docs/manual/index.html", content: "<html></html>")
    write_site_file(
      relative_path: "docs/manual/.docs-portal-build-manifest.json",
      content: JSON.pretty_generate(
        profile: Rails.env,
        source_commit: "abc123",
        entry_path: "docs/manual",
        build_result: "success"
      )
    )

    result = DocumentVersionQualityChecker.new(version).call

    check = result.infos.find { _1.key == :docusaurus_build_manifest }
    expect(check.message).to eq("Docusaurus build manifest source is set")
    expect(check.detail).to eq("docs/manual/.docs-portal-build-manifest.json")
  end

  it "reports manifest warnings" do
    write_site_file(relative_path: "docs/manual/index.html", content: "<html></html>")
    write_site_file(
      relative_path: "docs/manual/docs-portal-build-manifest.json",
      content: JSON.pretty_generate(
        profile: "production",
        source_commit: "old999",
        entry_path: "docs/other",
        build_result: "failed"
      )
    )

    result = DocumentVersionQualityChecker.new(version).call

    messages = result.warnings.select { _1.key == :docusaurus_build_manifest }.map(&:message)
    expect(messages).to include(
      "Docusaurus build profile does not match",
      "Docusaurus build source commit does not match",
      "Docusaurus build entry path does not match",
      "Docusaurus build manifest reports an unsuccessful build"
    )
  end
end
