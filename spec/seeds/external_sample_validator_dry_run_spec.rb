# frozen_string_literal: true

require "rails_helper"
require "fileutils"

require Rails.root.join("db/seeds/support/external_sample_validator").to_s

RSpec.describe SeedSupport::ExternalSampleValidator do
  def dry_run_payload(root)
    described_class.new(root:).call.to_h
  end

  it "reports missing roots as a dry-run warning without treating it as seed success" do
    root = Rails.root.join("tmp/spec/external_samples/missing-root")
    FileUtils.rm_rf(root)

    payload = dry_run_payload(root)

    expect(payload.fetch(:valid)).to be(true)
    expect(payload.fetch(:summary)).to include(
      projects: 0,
      documents: 0,
      document_versions: 0,
      attachments: 0
    )
    expect(payload.fetch(:warnings)).to include(
      include(level: "warning", code: "root_missing", path: "tmp/spec/external_samples/missing-root")
    )
    expect(payload.fetch(:errors)).to be_empty
    expect(payload.fetch(:note)).to include("dry-run only")
    expect(payload.fetch(:note)).to include("db:seed")
    expect(payload.fetch(:note)).to include("DocumentFile writes are not executed")
  ensure
    FileUtils.rm_rf(root)
  end

  it "reports non-directory roots as a machine-readable error before importer work" do
    root = Rails.root.join("tmp/spec/external_samples/not-a-directory")
    FileUtils.mkdir_p(root.dirname)
    File.write(root, "not a directory")

    payload = dry_run_payload(root)

    expect(payload.fetch(:valid)).to be(false)
    expect(payload.fetch(:candidates)).to be_empty
    expect(payload.fetch(:warnings)).to be_empty
    expect(payload.fetch(:errors)).to contain_exactly(
      include(level: "error", code: "root_not_directory", path: "tmp/spec/external_samples/not-a-directory")
    )
    expect(payload.fetch(:note)).to include("standard showcase regeneration")
    expect(payload.fetch(:note)).to include("CSV seed")
  ensure
    FileUtils.rm_f(root)
  end
end
