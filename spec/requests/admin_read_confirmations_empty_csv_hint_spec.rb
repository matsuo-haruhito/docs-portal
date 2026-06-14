require "rails_helper"

RSpec.describe "Admin read confirmations empty CSV hint", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }
  let(:other_document) { create(:document, project:, title: "Policy", slug: "policy") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def csv_export_link
    parsed_html.css("a").find { |link| link.text.squish == "CSV出力" }
  end

  before do
    create(:read_confirmation, document: other_document, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)
  end

  it "explains that CSV export keeps the empty filtered result" do
    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug, user_id: viewer.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("選択した条件に一致する既読確認はありません。")
    expect(page_text).to include("文書・期間・会社・確認者の組み合わせを見直すか、案件だけを残して条件を解除してください。")
    expect(page_text).to include("CSV出力は現在の絞り込み条件とページ範囲を反映します。この状態で出力すると、ヘッダーのみの空のCSVになります。")
    expect(page_text).to include("案件だけ残して条件を解除")
    expect(csv_export_link["href"]).to include("document_slug=manual")
    expect(csv_export_link["href"]).to include("user_id=#{viewer.id}")
  end

  it "keeps unmatched document empty state separate from the generic CSV hint" do
    get admin_read_confirmations_path(project_id: project.id, document_slug: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した文書URL識別子に一致する文書がないため、既読確認は表示されません。")
    expect(page_text).not_to include("この状態で出力すると、ヘッダーのみの空のCSVになります。")
  end
end
