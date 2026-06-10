require "rails_helper"

RSpec.describe "Document delivery logs empty states", type: :request do
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

  def href_for(text)
    parsed_html.css("a[href]").find { |node| node.text.strip == text }&.[]("href")
  end

  def create_delivery_log_at(created_at, attributes = {})
    create(
      :document_delivery_log,
      {
        project:,
        document:,
        sender: external_user,
        status: :draft,
        delivery_type: :portal_link,
        to_addresses: "recipient@example.com",
        subject: "Delivery notice"
      }.merge(attributes)
    ).tap do |log|
      log.update_columns(created_at:, updated_at: created_at)
    end
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "suggests reviewing date conditions when date filters return no delivery logs" do
    outside_date_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 5, 12, 0, 0),
      to_addresses: "outside-date@example.com"
    )

    sign_in_as(external_user)

    get document_delivery_logs_path, params: { created_from: "2026-01-10" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する送付履歴はありません。")
    expect(page_text).to include("検索語・状態・方式・日付条件を見直すか、「すべての送付履歴を見る」で条件を解除してください。")
    expect(page_text).not_to include(outside_date_log.to_addresses)
    expect(href_for("作成日をクリア")).to eq(document_delivery_logs_path)
    expect(href_for("すべての送付履歴を見る")).to eq(document_delivery_logs_path)
  end
end
