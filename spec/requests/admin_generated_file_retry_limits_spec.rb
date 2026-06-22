require "rails_helper"

RSpec.describe "Admin generated file retry limit notices", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows the generated file run bulk retry limit" do
    sign_in_as(admin_user)
    create(:generated_file_run, status: :failed)

    get admin_generated_file_runs_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("現在の条件で再実行対象")
    expect(response.body).to include("このボタンは現在の絞り込み条件に一致する失敗履歴だけを対象にします。")
    expect(response.body).to include("古い順に最大100件です。")
  end

  it "shows the generated file event bulk retry limit" do
    sign_in_as(admin_user)
    create(:generated_file_event, status: :failed, scheduled_at: 1.minute.ago)

    get admin_generated_file_events_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("一括再投入は古い失敗分から最大100件です。")
  end
end
