require "rails_helper"

RSpec.describe "Document delivery log empty states", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
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

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "shows a condition-specific empty state for search misses" do
    sign_in_as(internal_user)

    get document_delivery_logs_path, params: { q: "missing recipient" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する送付履歴はありません。")
    expect(page_text).to include("検索語・状態・方式を見直すか、「すべての送付履歴を見る」で条件を解除してください。")
    expect(href_for("すべての送付履歴を見る")).to eq(document_delivery_logs_path)
  end

  it "shows a condition-specific empty state for status and delivery type misses" do
    create(:document_delivery_log, project:, document:, sender: external_user, status: :draft, delivery_type: :portal_link, to_addresses: "draft@example.com")

    sign_in_as(external_user)

    get document_delivery_logs_path, params: { status: :failed, delivery_type: :portal_link }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する送付履歴はありません。")
    expect(page_text).to include("検索語・状態・方式を見直すか、「すべての送付履歴を見る」で条件を解除してください。")
    expect(href_for("すべての送付履歴を見る")).to eq(document_delivery_logs_path)
  end
end
