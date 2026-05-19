require "rails_helper"
require "fileutils"

RSpec.describe DocusaurusBuildManifest do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) do
    create(
      :document_version,
      document:,
      source_commit_hash: "abc123",
      markdown_entry_path: "docs/guide",
      site_build_path: "docs/guide"
    )
  end

  after do
    FileUtils.rm_rf(version.site_root_absolute_path)
  end

  def write_manifest(path:, data:)
    absolute_path = version.site_root_absolute_path.join(path)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, JSON.pretty_generate(data))
  end

  it "reads a manifest from the site build directory" do
    write_manifest(
      path: "docs/guide/.docs-portal-build-manifest.json",
      data: {
        profile: "test",
        source_commit: "abc123",
        built_at: "2026-05-20T00:00:00Z",
        entry_path: "docs/guide",
        build_result: "success"
      }
    )

    result = described_class.new(version, expected_profile: "test", now: Time.zone.parse("2026-05-21T00:00:00Z")).call

    expect(result).to be_valid
    expect(result.source_path).to eq("docs/guide/.docs-portal-build-manifest.json")
    expect(result.profile).to eq("test")
    expect(result.source_commit).to eq("abc123")
    expect(result.entry_path).to eq("docs/guide")
    expect(result.build_result).to eq("success")
  end

  it "warns when the manifest is missing" do
    result = described_class.new(version, expected_profile: "test").call

    warning = result.warnings.find { _1.code == :manifest_missing }
    expect(warning.message).to include("manifest is missing")
    expect(warning.detail).to eq("docs/guide/.docs-portal-build-manifest.json")
  end

  it "warns about profile, source commit, entry path, and build result mismatches" do
    write_manifest(
      path: "docs/guide/docs-portal-build-manifest.json",
      data: {
        profile: "production",
        source_commit: "old999",
        entry_path: "docs/other",
        build_result: "failed"
      }
    )

    result = described_class.new(version, expected_profile: "test").call

    expect(result.warnings.map(&:code)).to include(
      :profile_mismatch,
      :source_commit_mismatch,
      :entry_path_mismatch,
      :build_result_failed
    )
  end

  it "warns when built_at is older than the stale build threshold" do
    write_manifest(
      path: "docs/guide/build-manifest.json",
      data: {
        profile: "test",
        source_commit: "abc123",
        built_at: "2026-05-01T00:00:00Z",
        entry_path: "docs/guide",
        build_result: "success"
      }
    )

    result = described_class.new(
      version,
      expected_profile: "test",
      now: Time.zone.parse("2026-05-20T00:00:00Z"),
      stale_build_age: 7.days
    ).call

    warning = result.warnings.find { _1.code == :stale_build }
    expect(warning.message).to include("manifest is stale")
    expect(warning.detail).to eq("2026-05-01T00:00:00Z")
  end
end
