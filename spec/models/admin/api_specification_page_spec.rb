require "rails_helper"
require "fileutils"
require "json"

RSpec.describe Admin::ApiSpecificationPage do
  let(:page) { described_class.new }
  let(:build_status_marker_path) { Rails.root.join("tmp", "api_specification_build.status.json") }
  let(:build_history_marker_path) { Rails.root.join("tmp", "api_specification_build.history.json") }
  let(:build_request_marker_path) { Rails.root.join("tmp", "api_specification_build.requested") }
  let(:build_entry_path) { page.build_entry_path }
  let(:build_manifest_path) { page.build_manifest_path }

  after do
    FileUtils.rm_f(build_status_marker_path)
    FileUtils.rm_f(build_history_marker_path)
    FileUtils.rm_f(build_request_marker_path)
    FileUtils.rm_f(build_entry_path)
    FileUtils.rm_f(build_manifest_path)
  end

  describe "#primary_source_pages" do
    it "keeps the admin source list labels, site paths, and source paths together" do
      expect(page.primary_source_pages.map { |source_page| [source_page.label, source_page.site_path, source_page.source_path] }).to eq([
        ["API仕様・連携設定", "api-specification", "docs-src/api-specification.md"],
        ["単体ファイルアップロードAPI", "client-file-upload-api", "docs-src/client-file-upload-api.md"],
        ["Office preview", "office-preview", "docs-src/office-preview.md"],
        ["外部フォルダ同期 Webhook 受信仕様", "external-folder-sync-webhooks", "docs-src/external-folder-sync-webhooks.md"]
      ])
      expect(page.primary_source_paths).to eq(page.primary_source_pages.map(&:source_path))
    end
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
      manifest = JSON.parse(build_manifest_path.read)
      expect(marker["status"]).to eq("success")
      expect(manifest).to include(
        "profile" => Admin::ApiSpecificationPage::BUILD_PROFILE,
        "validation_result" => "success",
        "source_path" => "docs-src/api-specification.md"
      )
      expect(manifest["built_at"]).to be_present
      expect(manifest["docusaurus_version"]).to be_present
      expect(page.build_status.label).to eq("最新 build 成功")
      expect(page.build_status.message).not_to include("old failure")
      expect(page.build_manifest.label).to eq("build manifest 確認済み")
      expect(page.build_manifest.profile).to eq(Admin::ApiSpecificationPage::BUILD_PROFILE)
      expect(page.build_manifest.docusaurus_version).to be_present
      expect(page.build_history.first.label).to eq("最新 build 成功")
      expect(page.build_history.first.success_at).to be_present
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
      expect(build_manifest_path).not_to exist
      expect(page.build_status.label).to eq("build 失敗")
      expect(page.build_history.first.label).to eq("build 失敗")
      expect(page.build_history.first.message).to include("token=[FILTERED]")
      expect(page.build_history.first.message).not_to include("secret-value")
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

  describe "#build_manifest" do
    it "falls back safely when the manifest is missing" do
      manifest = page.build_manifest

      expect(manifest.label).to eq("build manifest 未記録")
      expect(manifest.state).to eq(:missing)
      expect(manifest.profile).to eq("未記録")
    end

    it "falls back safely when the manifest JSON is invalid" do
      FileUtils.mkdir_p(build_manifest_path.dirname)
      File.write(build_manifest_path, "{invalid")

      manifest = page.build_manifest

      expect(manifest.label).to eq("build manifest 読み取り不可")
      expect(manifest.state).to eq(:warning)
      expect(manifest.profile).to eq("読み取り不可")
    end

    it "warns without blocking when the manifest profile does not match admin_api_spec" do
      FileUtils.mkdir_p(build_manifest_path.dirname)
      File.write(
        build_manifest_path,
        JSON.generate(
          profile: "portal_embedded",
          built_at: Time.current.iso8601,
          docusaurus_version: "3.7.0",
          validation_result: "success",
          source_path: "docs-src/api-specification.md"
        )
      )

      manifest = page.build_manifest

      expect(manifest.label).to eq("build manifest profile 不一致")
      expect(manifest.state).to eq(:warning)
      expect(manifest.profile).to eq("portal_embedded")
      expect(manifest.docusaurus_version).to eq("3.7.0")
      expect(manifest.validation_result).to eq("success")
    end
  end

  describe "#build_history" do
    it "keeps the newest API specification build history entries within the limit" do
      FileUtils.mkdir_p(build_history_marker_path.dirname)
      history = 6.times.map do |index|
        {
          status: "failed",
          recorded_at: (Time.zone.local(2026, 6, 1, 9, 0, 0) + index.minutes).iso8601,
          message: "failure #{index}"
        }
      end
      File.write(build_history_marker_path, JSON.pretty_generate(history))

      entries = page.build_history

      expect(entries.size).to eq(Admin::ApiSpecificationPage::BUILD_HISTORY_LIMIT)
      expect(entries.map(&:message)).to eq(["failure 0", "failure 1", "failure 2", "failure 3", "failure 4"])
    end

    it "adds the current requested marker to the read-only history without changing build status precedence" do
      FileUtils.mkdir_p(build_request_marker_path.dirname)
      File.write(build_request_marker_path, Time.current.iso8601)
      File.write(build_history_marker_path, JSON.pretty_generate([
        { status: "failed", recorded_at: 1.hour.ago.iso8601, message: "previous failure" }
      ]))

      entries = page.build_history

      expect(entries.first.label).to eq("build 待ち/実行中")
      expect(entries.first.requested_at).to be_present
      expect(entries.second.label).to eq("build 失敗")
    end
  end
end
