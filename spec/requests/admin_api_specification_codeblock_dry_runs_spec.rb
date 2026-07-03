require "rails_helper"

RSpec.describe "Admin API specification codeblock dry-runs", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "validates an internal http codeblock without applying or sending anything" do
    sign_in_as(admin_user)

    post codeblock_dry_run_admin_api_specification_path,
      params: {
        codeblock_id: "internal-file-upload-sample",
        codeblock: <<~HTTP
          POST /api/internal/file_uploads HTTP/1.1
          Content-Type: multipart/form-data
        HTTP
      },
      as: :json

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload["status"]).to eq("ok")
    expect(payload["dry_run"]).to eq(true)
    expect(payload["destructive"]).to eq(false)
    expect(payload["action_kind"]).to eq("admin_api_spec.http_codeblock_dry_run")
    expect(payload["target_viewer"]).to eq("admin_api_specification")
    expect(payload["target_api"]).to eq("POST /api/internal/file_uploads")
    expect(payload["codeblock_id"]).to eq("internal-file-upload-sample")
    expect(payload["user"]).to eq(admin_user.display_name)
    expect(payload["message"]).to include("apply / import / 外部送信は実行していません")
  end

  it "rejects external URL samples so the dry-run stays local only" do
    sign_in_as(admin_user)

    post codeblock_dry_run_admin_api_specification_path,
      params: {
        codeblock_id: "external-sample",
        codeblock: "GET https://example.com/api HTTP/1.1"
      },
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    payload = JSON.parse(response.body)
    expect(payload["status"]).to eq("error")
    expect(payload["dry_run"]).to eq(true)
    expect(payload["destructive"]).to eq(false)
    expect(payload["message"]).to include("外部 URL")
  end

  it "rejects non-http codeblocks" do
    sign_in_as(admin_user)

    post codeblock_dry_run_admin_api_specification_path,
      params: {
        codeblock_id: "shell-sample",
        codeblock: "curl -X POST /api/internal/file_uploads"
      },
      as: :json

    expect(response).to have_http_status(:unprocessable_entity)
    payload = JSON.parse(response.body)
    expect(payload["status"]).to eq("error")
    expect(payload["message"]).to include("サポート対象外")
  end

  it "keeps the dry-run endpoint limited to internal admins" do
    sign_in_as(create(:user, :company_master_admin))

    post codeblock_dry_run_admin_api_specification_path,
      params: { codeblock: "GET /api/internal/file_uploads HTTP/1.1" },
      as: :json

    expect(response).to have_http_status(:forbidden)
  end

  it "keeps the viewer hook scoped to the admin API specification iframe" do
    view_source = Rails.root.join("app/views/admin/api_specifications/show.html.slim").read
    controller_source = Rails.root.join("app/frontend/controllers/api_specification_codeblock_dry_run_controller.js").read
    entrypoint_source = Rails.root.join("app/frontend/entrypoints/application.js").read

    expect(view_source).to include("data-controller=\"api-specification-codeblock-dry-run\"")
    expect(view_source).to include("data-api-specification-codeblock-dry-run-url-value=codeblock_dry_run_admin_api_specification_path")
    expect(view_source).to include("data-api-specification-codeblock-dry-run-target=\"frame\"")
    expect(controller_source).to include("pre code.language-http")
    expect(controller_source).to include("window.confirm")
    expect(controller_source).to include("apply / import / 外部送信は行いません")
    expect(entrypoint_source).to include("api-specification-codeblock-dry-run")
  end
end
