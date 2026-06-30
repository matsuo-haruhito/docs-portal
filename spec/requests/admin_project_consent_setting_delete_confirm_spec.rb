require "rails_helper"

RSpec.describe "Admin project consent setting delete confirmation", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  it "identifies the project, consent term, version, and required timing in the delete confirm" do
    project = create(:project, code: "ALPHA", name: "Alpha Project")
    consent_term = create(:consent_term, title: "Portal Terms", version_label: "v1", consent_scope: :project)
    create(:project_consent_setting, project:, consent_term:, required_on: :first_access, enabled: true)

    get admin_project_consent_settings_path

    expect(response).to have_http_status(:ok)
    setting_row = parsed_html.css("tbody tr").find do |row|
      row.text.squish.include?("Alpha Project") && row.text.squish.include?("Portal Terms")
    end
    expect(setting_row).to be_present
    delete_link = setting_row.css("a, button").find { _1.text.squish == "削除" }
    expect(delete_link).to be_present
    expect(delete_confirm(delete_link)).to include(
      "案件「Alpha Project (ALPHA)」",
      "同意文面「Portal Terms / v1（閲覧前）」",
      "設定を削除しますか？"
    )
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def delete_confirm(link)
    link["data-turbo-confirm"].presence ||
      link["data-confirm"].presence ||
      link["onclick"].presence ||
      link.ancestors("form").first&.[]("data-turbo-confirm") ||
      ""
  end
end
