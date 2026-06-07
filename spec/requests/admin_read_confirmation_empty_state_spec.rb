require "rails_helper"

RSpec.describe "Admin read confirmation empty state", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "READZERO", name: "Read Zero Project") }
  let(:other_project) { create(:project, code: "OTHERZERO", name: "Other Zero Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader-one@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_rows
    parsed_html.css("table tbody tr").map { _1.text.squish }
  end

  def link_href(label)
    parsed_html.css("a").find { _1.text.squish == label }&.[]("href")
  end

  it "shows condition-review copy and a project-only reset link for a valid zero-result combination" do
    other_viewer = create(:user, :external, name: "Reader Two", email_address: "reader-two@example.com")
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: other_viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug, user_id: other_viewer.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 文書名: Manual")
    expect(page_text).to include("確認者: Reader Two / reader-two@example.com")
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("選択した条件に一致する既読確認はありません。")
    expect(page_text).to include("文書・期間・会社・確認者の組み合わせを見直すか、案件だけを残して条件を解除してください。")
    expect(link_href("案件だけ残して条件を解除")).to eq(admin_read_confirmations_path(project_id: project.id))
    expect(read_confirmation_rows).to be_empty
  end

  it "keeps the missing-document empty state separate from valid condition misses" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した文書はこの案件に見つかりません。")
    expect(page_text).to include("指定した文書URL識別子に一致する文書がないため、既読確認は表示されません。")
    expect(page_text).not_to include("文書・期間・会社・確認者の組み合わせを見直すか")
    expect(link_href("案件だけ残して条件を解除")).to be_nil
  end

  it "keeps company and user candidate misses on their existing copy paths" do
    outside_company = create(:company, name: "Outside Client", domain: "outside-client.example")
    outside_viewer = create(:user, :external, company: outside_company, name: "Outside Reader", email_address: "outside@example.com")
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    create(:read_confirmation, document: outside_document, user: outside_viewer)

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, company_id: outside_company.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した会社はこの案件の既読確認候補に見つからないため、既読確認は表示されません。")
    expect(page_text).not_to include("文書・期間・会社・確認者の組み合わせを見直すか")

    get admin_read_confirmations_path(project_id: project.id, user_id: outside_viewer.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した確認者はこの案件の既読確認候補に見つからないため、既読確認は表示されません。")
    expect(page_text).not_to include("文書・期間・会社・確認者の組み合わせを見直すか")
  end
end
