require "rails_helper"

RSpec.describe "Document delivery log manual update visibility", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def action_labels
    parsed_html.css("a, button, input[type='submit']").map { |node| node["value"].presence || node.text.strip }
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
    sign_in_as(external_user)
  end

  it "keeps manual update actions visible for draft delivery logs" do
    draft_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :draft,
      delivery_type: :portal_link,
      to_addresses: "draft@example.com"
    )

    get document_delivery_log_path(draft_log)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("手動状態更新")
    expect(action_labels).to include("送付済みにする", "送付失敗として記録")
    expect(page_text).not_to include("この履歴は下書きではないため、状態を手動で変更する操作は表示されません。")
  end

  it "explains why manual update actions are hidden after the draft status has ended" do
    sent_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :sent,
      delivery_type: :portal_link,
      to_addresses: "sent@example.com",
      sent_at: 1.day.ago
    )
    failed_log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status: :failed,
      delivery_type: :portal_link,
      to_addresses: "failed@example.com",
      error_message: "delivery failed"
    )

    [sent_log, failed_log].each do |delivery_log|
      get document_delivery_log_path(delivery_log)

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("この履歴は下書きではないため、状態を手動で変更する操作は表示されません。")
      expect(page_text).to include("送付済み・送付失敗済みの記録は過去記録として確認してください。")
      expect(page_text).not_to include("手動状態更新")
      expect(action_labels).not_to include("送付済みにする", "送付失敗として記録")
      expect(parsed_html.css("form input[name='decision']")).to be_empty
    end
  end
end
