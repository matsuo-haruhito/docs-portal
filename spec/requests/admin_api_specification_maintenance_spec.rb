require "rails_helper"
require "fileutils"
require "json"

RSpec.describe "Admin API specification maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:page) { Admin::ApiSpecificationPage.new }
  let(:build_request_marker_path) { Rails.root.join("tmp", "api_specification_build.requested") }
  let(:build_status_marker_path) { Rails.root.join("tmp", "api_specification_build.status.json") }
  let(:build_history_marker_path) { Rails.root.join("tmp", "api_specification_build.history.json") }
  let(:build_entry_path) { page.build_entry_path }
  let(:build_manifest_path) { page.build_manifest_path }

  around do |example|
    original_value = ENV[Admin::ApiSpecificationsController::READ_ONLY_MAINTENANCE_ENV]
    ENV[Admin::ApiSpecificationsController::READ_ONLY_MAINTENANCE_ENV] = maintenance_env_value
    clear_api_specification_build_state!
    example.run
  ensure
    clear_api_specification_build_state!
    if original_value.nil?
      ENV.delete(Admin::ApiSpecificationsController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::ApiSpecificationsController::READ_ONLY_MAINTENANCE_ENV] = original_value
    end
  end

  describe "when read-only maintenance is enabled" do
    let(:maintenance_env_value) { "1" }

    it "keeps the API specification page readable without enqueueing a stale build" do
      sign_in_as(admin_user)
      allow(ApiSpecificationBuildJob).to receive(:perform_later)

      get admin_api_specification_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("API仕様")
      expect(response.body).to include("メンテナンス中のため API仕様ページの Docusaurus build は開始しません")
      expect(response.body).to include("生成済み HTML と source / status の確認は継続できます")
      expect(response.body).not_to include("API仕様ページの build を再実行")
      expect(ApiSpecificationBuildJob).not_to have_received(:perform_later)
      expect(build_request_marker_path).not_to exist
    end

    it "blocks manual retry_build without enqueueing a build request" do
      sign_in_as(admin_user)
      allow(ApiSpecificationBuildJob).to receive(:perform_later)

      post retry_build_admin_api_specification_path

      expect(response).to redirect_to(admin_api_specification_path)
      expect(ApiSpecificationBuildJob).not_to have_received(:perform_later)
      expect(build_request_marker_path).not_to exist

      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("メンテナンス中のためAPI仕様ページの build 再要求は停止しています")
    end

    it "keeps codeblock dry-run validation available without enqueueing a build" do
      sign_in_as(admin_user)
      allow(ApiSpecificationBuildJob).to receive(:perform_later)

      post codeblock_dry_run_admin_api_specification_path,
        params: {
          codeblock_id: "internal-upload-sample",
          codeblock: "POST /api/internal/file_uploads HTTP/1.1\nContent-Type: application/json"
        }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "status" => "ok",
        "dry_run" => true,
        "destructive" => false,
        "action_kind" => "admin_api_spec.http_codeblock_dry_run",
        "target_viewer" => "admin_api_specification",
        "target_api" => "POST /api/internal/file_uploads",
        "codeblock_id" => "internal-upload-sample"
      )
      expect(payload.fetch("message")).to include("apply / import / 外部送信は実行していません")
      expect(ApiSpecificationBuildJob).not_to have_received(:perform_later)
      expect(build_request_marker_path).not_to exist
    end

    it "keeps codeblock dry-run errors non-destructive during maintenance" do
      sign_in_as(admin_user)
      allow(ApiSpecificationBuildJob).to receive(:perform_later)

      post codeblock_dry_run_admin_api_specification_path,
        params: {
          codeblock_id: "external-url-sample",
          codeblock: "GET https://api.example.com/v1/documents HTTP/1.1"
        }

      expect(response).to have_http_status(:unprocessable_entity)
      payload = JSON.parse(response.body)
      expect(payload).to include(
        "status" => "error",
        "dry_run" => true,
        "destructive" => false,
        "action_kind" => "admin_api_spec.http_codeblock_dry_run",
        "target_viewer" => "admin_api_specification",
        "target_api" => "GET https://api.example.com/v1/documents",
        "codeblock_id" => "external-url-sample"
      )
      expect(payload.fetch("message")).to include("外部 URL への request sample は dry-run 対象外")
      expect(payload.fetch("details").join).to include("外部 API 送信を避ける")
      expect(ApiSpecificationBuildJob).not_to have_received(:perform_later)
      expect(build_request_marker_path).not_to exist
    end
  end

  describe "when read-only maintenance is disabled" do
    let(:maintenance_env_value) { nil }

    it "keeps the existing retry_build enqueue behavior for stale HTML" do
      sign_in_as(admin_user)
      allow(ApiSpecificationBuildJob).to receive(:perform_later)

      post retry_build_admin_api_specification_path

      expect(response).to redirect_to(admin_api_specification_path)
      expect(ApiSpecificationBuildJob).to have_received(:perform_later).once
      expect(build_request_marker_path).to exist
    end
  end

  def clear_api_specification_build_state!
    FileUtils.rm_f(build_request_marker_path)
    FileUtils.rm_f(build_status_marker_path)
    FileUtils.rm_f(build_history_marker_path)
    FileUtils.rm_f(build_entry_path)
    FileUtils.rm_f(build_manifest_path)
  end
end
