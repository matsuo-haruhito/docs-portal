require "rails_helper"

RSpec.describe "Admin generated file empty states", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows an initial empty state for generated file runs with no rows" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("生成ファイル実行履歴はまだありません。")
    expect(response.body).not_to include("条件に一致する生成ファイル実行履歴はありません。")
    expect(response.body).not_to include("すべての生成ファイル実行履歴を見る")
  end

  it "shows a filtered empty state for generated file runs with no matching rows" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する生成ファイル実行履歴はありません。")
    expect(response.body).to include("これは表示フィルタの結果です。")
    expect(response.body).to include("条件を見直すか、すべての生成ファイル実行履歴を表示してください。")
    expect(response.body).to include("すべての生成ファイル実行履歴を見る")
    expect(response.body).to include(%(href="#{admin_generated_file_runs_path}"))
  end

  it "shows an initial empty state for generated file events with no rows" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("生成ファイルイベントはまだありません。")
    expect(response.body).not_to include("検索条件に一致する生成ファイルイベントはありません。")
  end

  it "shows a filtered empty state for generated file events with no matching rows" do
    sign_in_as(admin_user)

    get admin_generated_file_events_path(status: "failed")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("検索条件に一致する生成ファイルイベントはありません。")
    expect(response.body).to include("これは表示フィルタの結果です。")
    expect(response.body).to include("一括再dispatch対象の有無とは別に")
    expect(response.body).to include("すべての生成ファイルイベントを見る")
  end
end
