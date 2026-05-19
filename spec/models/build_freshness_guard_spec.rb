require "rails_helper"
require "fileutils"
require "securerandom"

RSpec.describe BuildFreshnessGuard do
  class BuildFreshnessGuardSpecJob < ApplicationJob
    cattr_accessor :performed_count, default: 0
    cattr_accessor :raise_on_enqueue, default: false

    def self.perform_later
      raise "enqueue failed" if raise_on_enqueue

      self.performed_count += 1
    end
  end

  let(:workspace) { Rails.root.join("tmp", "build-freshness-#{SecureRandom.hex(4)}") }
  let(:source_path) { workspace.join("source.md") }
  let(:build_entry_path) { workspace.join("build", "index.html") }
  let(:marker_path) { workspace.join("build.requested") }
  let(:guard) do
    described_class.new(
      source_path:,
      build_entry_path:,
      marker_path:,
      job_class: BuildFreshnessGuardSpecJob
    )
  end

  before do
    BuildFreshnessGuardSpecJob.performed_count = 0
    BuildFreshnessGuardSpecJob.raise_on_enqueue = false
    FileUtils.mkdir_p(workspace)
  end

  after do
    FileUtils.rm_rf(workspace)
  end

  it "is stale when the build entry is missing" do
    File.write(source_path, "source")

    expect(guard).to be_stale
  end

  it "is stale when the source is newer than the build entry" do
    FileUtils.mkdir_p(build_entry_path.dirname)
    File.write(source_path, "source")
    File.write(build_entry_path, "html")
    File.utime(2.hours.ago.to_time, 2.hours.ago.to_time, build_entry_path)
    File.utime(1.hour.ago.to_time, 1.hour.ago.to_time, source_path)

    expect(guard).to be_stale
  end

  it "is stale when any watched source is newer than the build entry" do
    extra_source_path = workspace.join("extra.md")
    multi_source_guard = described_class.new(
      source_path: source_path,
      source_paths: [source_path, extra_source_path],
      build_entry_path: build_entry_path,
      marker_path: marker_path,
      job_class: BuildFreshnessGuardSpecJob
    )

    FileUtils.mkdir_p(build_entry_path.dirname)
    File.write(source_path, "source")
    File.write(extra_source_path, "extra")
    File.write(build_entry_path, "html")
    File.utime(3.hours.ago.to_time, 3.hours.ago.to_time, source_path)
    File.utime(2.hours.ago.to_time, 2.hours.ago.to_time, build_entry_path)
    File.utime(1.hour.ago.to_time, 1.hour.ago.to_time, extra_source_path)

    expect(multi_source_guard).to be_stale
  end

  it "does not enqueue more than once while a marker exists" do
    File.write(source_path, "source")

    expect(guard.enqueue_if_stale!).to eq(true)
    expect(guard.enqueue_if_stale!).to eq(false)
    expect(BuildFreshnessGuardSpecJob.performed_count).to eq(1)
    expect(marker_path).to exist
  end

  it "clears the build request marker" do
    guard.request_build!

    guard.clear_build_request!

    expect(marker_path).not_to exist
  end

  it "clears the marker when enqueue fails" do
    File.write(source_path, "source")
    BuildFreshnessGuardSpecJob.raise_on_enqueue = true

    expect { guard.enqueue_if_stale! }.to raise_error("enqueue failed")
    expect(marker_path).not_to exist
  end
end
