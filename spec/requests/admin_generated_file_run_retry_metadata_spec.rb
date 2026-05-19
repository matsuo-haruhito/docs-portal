require "rails_helper"

RSpec.describe "Admin generated file run retry metadata", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "surfaces retry metadata on the run detail page" do
    sign_in_as(admin_user)
    run = create(:generated_file_run, metadata: {
      "retry_of_generated_file_run_public_id" => "gfr_original",
      "retry_requested_at" => "2026-05-20T10:00:00+09:00"
    })

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Retry Of")
    expect(response.body).to include("gfr_original")
    expect(response.body).to include("Retry Requested")
    expect(response.body).to include("2026-05-20T10:00:00+09:00")
  end
end
