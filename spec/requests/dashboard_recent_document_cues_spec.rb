require "rails_helper"

RSpec.describe "Dashboard recent document cues", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Cue Project") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def dashboard_section_text(title)
    parsed_html.css(".dashboard-grid .card").find do |section|
      section.at_css("h2")&.text&.squish == title
    end.text.squish
  end

  def create_viewable_document(title:, slug:, updated_at: Time.current)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external, updated_at:)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  before do
    create(:project_membership, project:, user:)
  end

  it "distinguishes personal recent history from recently updated documents" do
    viewed_document = create_viewable_document(title: "Viewed Manual", slug: "viewed-manual", updated_at: 2.days.ago)
    updated_document = create_viewable_document(title: "Updated Manual", slug: "updated-manual", updated_at: 1.hour.ago)
    create(:access_log, user:, company:, project:, document: viewed_document, action_type: :view, target_type: "document", accessed_at: Time.current)

    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(dashboard_section_text("最近見た文書")).to include(
        "あなたの閲覧履歴から表示しています。",
        "作業再開用の個人履歴",
        "あなたが最近閲覧",
        "Viewed Manual"
      )
      expect(dashboard_section_text("最近更新された文書")).to include(
        "閲覧可能な文書を更新日時の新しい順に表示しています。",
        "未読通知ではなく、更新候補を確認する入口",
        "更新日時",
        "Updated Manual"
      )
    end
  end

  it "explains empty recent sections without implying permission errors" do
    sign_in_as(user)
    get dashboard_path

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(dashboard_section_text("最近見た文書")).to include(
        "まだ閲覧履歴がない状態",
        "権限不足やエラーではなく"
      )
      expect(dashboard_section_text("最近更新された文書")).to include(
        "閲覧可能な範囲に更新候補がない状態",
        "権限エラーではなく"
      )
    end
  end
end
