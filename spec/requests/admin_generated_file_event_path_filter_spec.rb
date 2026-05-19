require "rails_helper"

RSpec.describe "Admin generated file event path filter escaping", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "treats underscore characters in path filters as literals" do
    sign_in_as(admin_user)
    literal = create(:generated_file_event, path: "docs/a_b.yml")
    wildcard_match = create(:generated_file_event, path: "docs/axb.yml")

    get admin_generated_file_events_path(path: "a_b")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(literal.public_id)
    expect(response.body).not_to include(wildcard_match.public_id)
  end

  it "treats percent characters in path filters as literals" do
    sign_in_as(admin_user)
    literal = create(:generated_file_event, path: "docs/a%b.yml")
    wildcard_match = create(:generated_file_event, path: "docs/anything-between-a-and-b.yml")

    get admin_generated_file_events_path(path: "a%b")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(literal.public_id)
    expect(response.body).not_to include(wildcard_match.public_id)
  end
end
