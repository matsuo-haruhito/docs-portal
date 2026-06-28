require "rails_helper"

RSpec.describe "Admin generated file JSON detail defaults", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows empty JSON arrays and objects for generated file run details" do
    sign_in_as(admin_user)
    run = create(
      :generated_file_run,
      source_paths: [],
      changed_files: [],
      generated_paths: [],
      metadata: {}
    )

    get admin_generated_file_run_path(run.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("[]")
    expect(response.body).to include("{}")
  end

  it "shows an explicit empty state for generated file event metadata" do
    sign_in_as(admin_user)
    event = create(:generated_file_event, metadata: {})

    get admin_generated_file_event_path(event.public_id)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("このイベントに補助メタデータはありません。")
  end
end
