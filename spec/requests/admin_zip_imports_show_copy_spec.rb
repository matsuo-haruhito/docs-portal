require "rails_helper"

RSpec.describe "Admin zip import dry-run detail copy", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ZIPUI", name: "ZIP UI Project") }

  it "shows localized status and tree change labels" do
    sign_in_as(admin_user)

    dry_run = ImportDryRun.create!(
      import_mode: :zip,
      status: :analyzed,
      project: project,
      created_by: admin_user,
      source_commit_hash: "deadbeef",
      summary_json: {
        "total" => 3,
        "create_count" => 1,
        "update_count" => 1,
        "warning_count" => 0
      },
      result_json: {
        "items" => [
          { "source_path" => "docs/new.md", "title" => "新規文書", "action" => "create" },
          { "source_path" => "docs/existing.md", "title" => "既存文書", "action" => "update" },
          { "source_path" => "docs/review.md", "title" => "確認文書", "action" => "noop" }
        ]
      },
      warnings_json: [],
      errors_json: []
    )

    get admin_zip_import_path(dry_run)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("解析済み")
    expect(response.body).to include("新規")
    expect(response.body).to include("更新")
    expect(response.body).to include("変更候補")
    expect(response.body).not_to include(">analyzed<")
    expect(response.body).not_to include(">create<")
    expect(response.body).not_to include(">update<")
  end
end
