require "rails_helper"
require "fileutils"
require "json"

RSpec.describe Admin::ApiSpecificationPage do
  let(:page) { described_class.new }
  let(:build_status_marker_path) { Rails.root.join("tmp", "api_specification_build.status.json") }
  let(:build_request_marker_path) { Rails.root.join("tmp", "api_specification_build.requested") }
  let(:build_entry_path) { page.build_entry_path }

  after do
    FileUtils.rm_f(build_status_marker_path)
    FileUtils.rm_f(build_request_marker_path)
    FileUtils.rm_f(build_entry_path)
  end

  describe "#source_paths" do
    it "includes all docs-src markdown files" do
      expect(page.source_paths).to include(Rails.root.join("docs-src", "api-specification.md"))
      expect(page.source_paths).to include(Rails.root.join("docs-src", "client-file-upload-api.md"))
    end
  end

  describe "#build!" do
    before do
      allow(SeedSupport::DocusaurusRuntimeChecker).to receive(:ensure_npm!)
    end

    it "records a successful build status and clears an older failure" do
      FileUtils.mkdir_p(build_status_marker_path.dirname)
      File.write(build_status_marker_path, JSON.generate(status: "failed", message: "old failure"))
      successful_status = instance_double(Process::Status, success?: true)
      allow(Open3).to receive(:capture3) do
        FileUtils.mkdir_p(build_entry_path.dirname)
        File.write(build_entry_path, "html")
        ["ok", "", successful_status]
      end

      page.build!

      marker = JSON.parse(build_status_marker_path.read)
      expect(marker["status"]).to eq("success")
      expect(page.build_status.label).to eq("最新 build 成功")
      expect(page.build_status.message).not_to include("old failure")
    end

    it "records a sanitized failure message without exposing long stderr, tokens, or absolute paths" do
      failed_status = instance_double(Process::Status, success?: false)
      long_error = "failed at #{Rails.root}/tmp/private/source token=secret-value #{'x' * 220}"
      allow(Open3).to receive(:capture3).and_return(["", long_error, failed_status])

      expect { page.build! }.to raise_error(RuntimeError)

      marker = JSON.parse(build_status_marker_path.read)
      expect(marker["status"]).to eq("failed")
      expect(marker["message"]).to include("token=[FILTERED]")
      expect(marker["message"]).not_to include(Rails.root.to_s)
      expect(marker["message"]).not_to include("secret-value")
      expect(marker["message"].length).to be <= Admin::ApiSpecificationPage::FAILURE_MESSAGE_MAX_LENGTH
      expect(page.build_status.label).to eq("build 失敗")
    end
  end

  describe "#build_status" do
    it "reports a requested build before stale or failed state" do
      FileUtils.mkdir_p(build_request_marker_path.dirname)
      File.write(build_request_marker_path, Time.current.iso8601)
      File.write(build_status_marker_path, JSON.generate(status: "failed", message: "previous failure"))

      status = page.build_status

      expect(status.label).to eq("build 待ち/実行中")
      expect(status.message).to include("完了後に再読み込み")
    end
  end
end
