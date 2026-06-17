require "rails_helper"

RSpec.describe "Document approval request section count cues", type: :request do
  let(:company) { create(:company) }
  let(:requester) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "APR-CUE", name: "Approval Cue Project") }
  let(:document) { create(:document, project:, title: "確認資料", slug: "approval-cue-doc", visibility_policy: :restricted_external) }

  def page_text
    Nokogiri::HTML(response.body).text.squish
  end

  before do
    create(:project_membership, project:, user: requester)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "labels section counts as current-filter counts when filters are active" do
    matching_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "契約レビュー依頼",
      body: "契約条項を確認してください"
    )
    approved_request = create(
      :document_approval_request,
      document:,
      requester:,
      title: "契約レビュー完了",
      status: :approved,
      acted_by: internal_user,
      approved_at: 1.hour.ago,
      cancelled_at: nil
    )

    sign_in_as(internal_user)

    get document_approval_requests_path, params: { status: :pending, q: "契約" }

    expect(response).to have_http_status(:ok)
    aggregate_failures do
      expect(page_text).to include("状態ボタンの件数は一覧全体の件数です")
      expect(page_text).to include("対応待ち 1件（表示中条件内）")
      expect(response.body).to include(matching_request.title)
      expect(response.body).not_to include(approved_request.title)
    end
  end
end
