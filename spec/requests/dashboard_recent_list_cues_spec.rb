require "rails_helper"

RSpec.describe "Dashboard recent list cues", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Visible Project") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def dashboard_section(title)
    parsed_html.css(".dashboard-grid .card").find do |section|
      section.at_css("h2")&.text&.squish == title
    end
  end

  def create_viewable_document(title:, slug:, updated_at: Time.current)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external, updated_at:)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  before do
    create(:project_membership, project:, user:)
  end

  it "distinguishes viewing-history documents from recently updated documents" do
    viewed_document = create_viewable_document(
      title: "Viewed Guide",
      slug: "viewed-guide",
      updated_at: 3.days.ago
    )
    updated_document = create_viewable_document(
      title: "Updated Guide",
      slug: "updated-guide",
      updated_at: Time.zone.local(2026, 1, 2, 9, 30)
    )
    create(
      :access_log,
      user:,
      company:,
      project:,
      document: viewed_document,
      action_type: :view,
      target_type: "document",
      accessed_at: Time.current
    )

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)

    viewed_section_text = dashboard_section("最近見た文書").text.squish
    updated_section_text = dashboard_section("最近更新された文書").text.squish

    expect(viewed_section_text).to include(
      "あなたの閲覧履歴から表示しています。",
      "Viewed Guide",
      "Visible Project / あなたが最近閲覧"
    )
    expect(viewed_section_text).not_to include("更新日時")
    expect(updated_section_text).to include(
      "閲覧可能な文書を更新日時の新しい順に表示しています。",
      "Updated Guide",
      "Visible Project / 更新日時 #{I18n.l(updated_document.updated_at, format: :short)}"
    )
  end
end
