require "rails_helper"

RSpec.describe "Admin generated file empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows an empty state for generated file runs with no matching rows" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する生成ファイル実行履歴はありません。")
  end

  it "shows an initial empty state for generated file events with no rows" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("生成ファイルイベントはまだありません。")
    expect(response.body).not_to include("条件に一致する生成ファイルイベントはありません。")
  end

  it "shows a filtered empty state for generated file events with no matching rows" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する生成ファイルイベントはありません。")
    expect(response.body).to include("条件を見直すか、クリアしてください。")
  end
end
