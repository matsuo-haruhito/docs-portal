require "rails_helper"

RSpec.describe "Admin read confirmation document slug cue", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "READCUE", name: "Read Cue Project") }
  let(:company) { create(:company, name: "Cue Client", domain: "cue-client.example") }
  let(:viewer) { create(:user, :external, company:, name: "Cue Reader", email_address: "cue-reader@example.com") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  it "shows the document search boundary beside the input" do
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    document_search = parsed_html.at_css("input[name='document_slug'][type='search']")

    expect(response).to have_http_status(:ok)
    expect(document_search).to be_present
    expect(document_search["maxlength"]).to eq(Admin::ReadConfirmationsController::DOCUMENT_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("最大100文字まで。選択した案件内の文書名またはURL識別子の一部一致で探します。")
  end

  it "keeps the multiple document match narrowing cue visible" do
    manual = create(:document, project:, title: "Manual", slug: "manual")
    appendix = create(:document, project:, title: "Manual Appendix", slug: "manual-appendix")
    policy = create(:document, project:, title: "Policy Manual", slug: "policy-manual")
    create(:read_confirmation, document: manual, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: appendix, user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: policy, user: viewer, confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "manual")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 一致文書: 3件")
    expect(page_text).to include("部分一致で複数の文書が対象です。候補を確認し、1件に絞る場合は文書名またはURL識別子を追加してください。")
    expect(page_text).to include("Manual / manual")
    expect(page_text).to include("Manual Appendix / manual-appendix")
    expect(page_text).to include("Policy Manual / policy-manual")
  end
end
