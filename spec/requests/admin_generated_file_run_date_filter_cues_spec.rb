require "rails_helper"

RSpec.describe "Admin generated file run date filter cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows day-boundary cues near the created date filters" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("作成日(開始)")
    expect(response.body).to include("日付だけ指定すると、その日の00:00以降を含みます。")
    expect(response.body).to include("作成日(終了)")
    expect(response.body).to include("日付だけ指定すると、その日の23:59までを含みます。")
  end

  it "keeps invalid datetime warnings visible with the new cues" do
    sign_in_as(admin_user)

    get admin_generated_file_runs_path(created_from: "invalid-date")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("日時フィルタを確認してください。")
    expect(response.body).to include("作成日(開始)「invalid-date」は日時として解釈できないため、この条件は適用していません。")
    expect(response.body).to include("日付だけ指定すると、その日の00:00以降を含みます。")
  end
end
