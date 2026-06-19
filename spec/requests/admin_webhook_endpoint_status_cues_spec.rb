require "rails_helper"

RSpec.describe "Admin webhook endpoint status cues", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def endpoint_row_for(name)
    Nokogiri::HTML(response.body).css("tbody tr").find do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="name"]))&.text&.squish == name
    end
  end

  it "shows the send and redelivery exclusion cue only for inactive endpoints" do
    sign_in_as(admin_user)

    create(:webhook_endpoint, name: "Active Hook", active: true, event_types: %w[document_updated])
    create(:webhook_endpoint, name: "Stopped Hook", active: false, event_types: %w[document_updated])

    get admin_webhook_endpoints_path

    expect(response).to have_http_status(:ok)

    active_row_text = endpoint_row_for("Active Hook").text.squish
    stopped_row_text = endpoint_row_for("Stopped Hook").text.squish

    expect(active_row_text).to include("有効")
    expect(active_row_text).not_to include("通常送信・手動再送の対象外")
    expect(stopped_row_text).to include("停止")
    expect(stopped_row_text).to include("通常送信・手動再送の対象外")
  end
end
