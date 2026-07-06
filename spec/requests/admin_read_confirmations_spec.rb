require "csv"
require "rails_helper"

RSpec.describe "Admin read confirmations", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company_master_admin) { create(:user, :external, :company_master_admin) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }
  let(:company) { create(:company, name: "Client A", domain: "client-a.example") }
  let(:viewer) { create(:user, :external, company:, name: "Reader One", email_address: "reader@example.com") }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def read_confirmation_row_nodes
    parsed_html.css("table tbody tr")
  end

  def read_confirmation_rows
    read_confirmation_row_nodes.map { _1.text.squish }
  end

  def company_filter_options
    parsed_html.css("select[name='company_id'] option").map { _1.text.squish }
  end

  def user_filter_options
    parsed_html.css("select[name='user_id'] option").map { _1.text.squish }
  end

  def csv_export_link
    parsed_html.css("a").find { |link| link.text.squish == "CSV出力" }
  end

  it "shows project read confirmation details to internal admins" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: create(:user, :external, name: "Reader Two"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: outside_document, user: create(:user, :external, name: "Outside Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("既読確認内訳")
    expect(page_text).to include("Usage Project")
    expect(page_text).to include("この画面は既読確認だけの内訳です。閲覧・ダウンロードの集計は文書利用状況で確認してください。")
    expect(page_text).to include("表示中: 2件 / 条件に一致した既読確認を新しい順に最新200件まで表示")
    expect(page_text).to include("Manual")
    expect(page_text).to include("Policy")
    expect(page_text).to include("Reader One / reader@example.com")
    expect(page_text).to include("Client A")
    expect(page_text).not_to include("Outside")
    expect(page_text).not_to include("Outside Reader")

    usage_report_link = parsed_html.at_css("a[href='#{admin_document_usage_reports_path(project_id: project.id)}']")
    expect(usage_report_link).to be_present
    expect(usage_report_link.text).to eq("文書利用状況へ戻る")
  end

  it "keeps long read confirmation row values readable" do
    long_company = create(:company, name: "International Operations and Compliance Review Company", domain: "long-client.example")
    long_user = create(
      :user,
      :external,
      company: long_company,
      name: "Reader With A Very Long Display Name For Audit Review",
      email_address: "reader.with.a.very.long.email.address.for.audit.review@example-client-domain.example"
    )
    long_document = create(
      :document,
      project:,
      title: "Very Long Compliance Manual Title For Regional Audit Confirmation Review",
      slug: "very-long-compliance-manual-title-for-regional-audit-confirmation-review"
    )
    create(:read_confirmation, document: long_document, user: long_user, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    row = read_confirmation_row_nodes.first

    expect(response).to have_http_status(:ok)
    expect(row.at_css(%(td[data-rails-table-preferences-column-key="document"]))["style"]).to include("overflow-wrap:anywhere")
    expect(row.at_css(%(td[data-rails-table-preferences-column-key="document"] a))["style"]).to include("word-break:break-word")
    expect(row.at_css(%(td[data-rails-table-preferences-column-key="user"]))["style"]).to include("overflow-wrap:anywhere")
    expect(row.at_css(%(td[data-rails-table-preferences-column-key="company"]))["style"]).to include("overflow-wrap:anywhere")
    expect(row.at_css(%(td[data-rails-table-preferences-column-key="document_slug"] code))["style"]).to include("white-space:normal")
    expect(page_text).to include(long_document.title)
    expect(page_text).to include(long_user.email_address)
    expect(page_text).to include(long_company.display_name)
    expect(page_text).to include(long_document.slug)
  end

  it "filters read confirmations by document slug within the selected project" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_same_slug = create(:document, project: other_project, title: "Outside Manual", slug: "manual")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: create(:user, :external, name: "Reader Two"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: outside_same_slug, user: create(:user, :external, name: "Outside Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 文書名: Manual")
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to include("Manual")
    expect(page_text).to include("Reader One")
    expect(page_text).not_to include("部分一致で複数の文書が対象です。")
    expect(page_text).not_to include("Policy")
    expect(page_text).not_to include("Outside Manual")
    expect(page_text).not_to include("Outside Reader")
    expect(read_confirmation_rows.size).to eq(1)
  end

  it "shows candidate cues when a document slug filter matches multiple documents" do
    appendix_document = create(:document, project:, title: "Manual Appendix", slug: "manual-appendix")
    policy_document = create(:document, project:, title: "Policy Manual", slug: "policy-manual")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: appendix_document, user: create(:user, :external, name: "Appendix Reader"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: policy_document, user: create(:user, :external, name: "Policy Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "manual")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 一致文書: 3件")
    expect(page_text).to include("部分一致で複数の文書が対象です。候補を確認し、1件に絞る場合は文書名またはURL識別子を追加してください。")
    expect(page_text).to include("Manual / manual")
    expect(page_text).to include("Manual Appendix / manual-appendix")
    expect(page_text).to include("Policy Manual / policy-manual")
    expect(page_text).to include("表示中: 3件")
    expect(read_confirmation_rows).to contain_exactly(
      a_string_including("Manual", "Reader One"),
      a_string_including("Manual Appendix", "Appendix Reader"),
      a_string_including("Policy Manual", "Policy Reader")
    )
  end

  it "normalizes oversized and blank document slug filters for display, filtering, and CSV links" do
    normalized_query = "alpha" * 20
    oversized_query = "#{normalized_query}should-not-leak"
    matching_document = create(:document, project:, title: "#{normalized_query} Guide", slug: "normalized-guide")
    create(:read_confirmation, document: matching_document, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: oversized_query)

    expect(response).to have_http_status(:ok)
    expect(normalized_query.length).to eq(Admin::ReadConfirmationsController::DOCUMENT_QUERY_MAX_LENGTH)
    expect(page_text).to include("文書URL識別子: #{normalized_query}")
    expect(page_text).not_to include("should-not-leak")
    expect(read_confirmation_rows).to contain_exactly(a_string_including(matching_document.title, "Reader One"))
    expect(parsed_html.at_css("input[name='document_slug'][type='search']")["value"]).to eq(normalized_query)
    expect(parsed_html.at_css("input[name='document_slug'][type='search']")["maxlength"]).to eq(Admin::ReadConfirmationsController::DOCUMENT_QUERY_MAX_LENGTH.to_s)
    expect(csv_export_link["href"]).to include("document_slug=#{normalized_query}")
    expect(csv_export_link["href"]).not_to include("should-not-leak")

    get admin_read_confirmations_path(project_id: project.id, document_slug: oversized_query, format: :csv)

    csv = CSV.parse(response.body, headers: true)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv.size).to eq(1)
    expect(csv.first.to_h).to include("文書名" => matching_document.title, "document slug" => matching_document.slug)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "   ")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書名またはURL識別子を指定しない場合は、案件内の既読確認を新しい順に表示します。")
    expect(parsed_html.at_css("input[name='document_slug'][type='search']")["value"]).to be_blank
    expect(csv_export_link["href"]).not_to include("document_slug")
  end

  it "filters read confirmations by company within the selected project" do
    other_company = create(:company, name: "Client B", domain: "client-b.example")
    outside_company = create(:company, name: "Outside Client", domain: "outside-client.example")
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    other_viewer = create(:user, :external, company: other_company, name: "Reader Two", email_address: "reader-two@example.com")
    outside_viewer = create(:user, :external, company: outside_company, name: "Outside Reader", email_address: "outside@example.com")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: other_viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: outside_document, user: outside_viewer, confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, company_id: company.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("会社: Client A")
    expect(page_text).to include("表示中: 1件")
    expect(read_confirmation_rows).to contain_exactly(a_string_including("Manual", "Reader One / reader@example.com", "Client A"))
    expect(read_confirmation_rows.join).not_to include("Policy")
    expect(read_confirmation_rows.join).not_to include("Reader Two")
    expect(read_confirmation_rows.join).not_to include("Outside")
    expect(company_filter_options).to include("Client A")
    expect(company_filter_options).to include("Client B")
    expect(company_filter_options).not_to include("Outside Client")
    expect(user_filter_options).to include("Reader One / reader@example.com / Client A")
    expect(user_filter_options).not_to include(a_string_including("Reader Two / reader-two@example.com"))
  end

  it "filters read confirmations by user within the selected project" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    other_viewer = create(:user, :external, name: "Reader Two", email_address: "reader-two@example.com")
    outside_viewer = create(:user, :external, name: "Outside Reader", email_address: "outside@example.com")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: other_viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document: outside_document, user: outside_viewer, confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, user_id: viewer.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("確認者: Reader One / reader@example.com / 会社: Client A")
    expect(page_text).to include("表示中: 1件")
    expect(read_confirmation_rows).to contain_exactly(a_string_including("Manual", "Reader One / reader@example.com"))
    expect(read_confirmation_rows.join).not_to include("Policy")
    expect(read_confirmation_rows.join).not_to include("Reader Two")
    expect(read_confirmation_rows.join).not_to include("Outside")
    expect(user_filter_options).to include("Reader One / reader@example.com / Client A")
    expect(user_filter_options).to include(a_string_including("Reader Two / reader-two@example.com"))
    expect(user_filter_options).not_to include(a_string_including("Outside Reader / outside@example.com"))
  end

  it "combines document slug, company, and user filters" do
    same_company_viewer = create(:user, :external, company:, name: "Reader Same Company", email_address: "same-company@example.com")
    other_company = create(:company, name: "Client B", domain: "client-b.example")
    other_company_viewer = create(:user, :external, company: other_company, name: "Reader Other Company", email_address: "other-company@example.com")
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document:, user: same_company_viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document:, user: other_company_viewer, confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: same_company_viewer, confirmed_at: Time.zone.local(2026, 5, 4, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      project_id: project.id,
      document_slug: document.slug,
      company_id: company.id,
      user_id: same_company_viewer.id
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 文書名: Manual")
    expect(page_text).to include("会社: Client A")
    expect(page_text).to include("確認者: Reader Same Company / same-company@example.com / 会社: Client A")
    expect(page_text).to include("表示中: 1件")
    expect(read_confirmation_rows).to contain_exactly(a_string_including("Manual", "Reader Same Company / same-company@example.com", "Client A"))
    expect(read_confirmation_rows.join).not_to include("Reader One")
    expect(read_confirmation_rows.join).not_to include("Reader Other Company")
    expect(read_confirmation_rows.join).not_to include("Policy")
  end

  it "combines document slug and user filters" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    other_viewer = create(:user, :external, name: "Reader Two", email_address: "reader-two@example.com")
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document: other_document, user: other_viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug, user_id: other_viewer.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書URL識別子: manual / 文書名: Manual")
    expect(page_text).to include("確認者: Reader Two / reader-two@example.com")
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("選択した条件に一致する既読確認はありません。")
    expect(read_confirmation_rows).to be_empty
  end

  it "does not accept a company filter from another project" do
    outside_company = create(:company, name: "Outside Client", domain: "outside-client.example")
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    outside_viewer = create(:user, :external, company: outside_company, name: "Outside Reader", email_address: "outside@example.com")
    create(:read_confirmation, document: outside_document, user: outside_viewer)

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, company_id: outside_company.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した会社はこの案件の既読確認候補に見つかりません。")
    expect(page_text).to include("表示中: 0件")
    expect(read_confirmation_rows).to be_empty
    expect(company_filter_options).not_to include("Outside Client")
    expect(user_filter_options).not_to include(a_string_including("Outside Reader / outside@example.com"))
  end

  it "does not accept a user filter from another project" do
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    outside_viewer = create(:user, :external, name: "Outside Reader", email_address: "outside@example.com")
    create(:read_confirmation, document: outside_document, user: outside_viewer)

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, user_id: outside_viewer.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した確認者はこの案件の既読確認候補に見つかりません。")
    expect(page_text).to include("表示中: 0件")
    expect(read_confirmation_rows).to be_empty
    expect(user_filter_options).not_to include(a_string_including("Outside Reader / outside@example.com"))
  end

  it "filters read confirmations by confirmed_at range while keeping document slug filtering" do
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual Before"), confirmed_at: Time.zone.local(2026, 4, 30, 23, 59, 59))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual Start"), confirmed_at: Time.zone.local(2026, 5, 1, 0, 0, 0))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual End"), confirmed_at: Time.zone.local(2026, 5, 3, 23, 59, 59))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Manual After"), confirmed_at: Time.zone.local(2026, 5, 4, 0, 0, 0))
    create(:read_confirmation, document: other_document, user: create(:user, :external, name: "Policy In Range"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: document.slug, from: "2026-05-01", to: "2026-05-03")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("既読確認日時の期間: 2026-05-01 から 2026-05-03 まで")
    expect(page_text).to include("文書利用状況の閲覧・ダウンロード集計期間とは別の条件です")
    expect(page_text).to include("表示中: 2件")
    expect(read_confirmation_rows.join).to include("Manual Start")
    expect(read_confirmation_rows.join).to include("Manual End")
    expect(read_confirmation_rows.join).not_to include("Manual Before")
    expect(read_confirmation_rows.join).not_to include("Manual After")
    expect(read_confirmation_rows.join).not_to include("Policy In Range")
    expect(parsed_html.at_css("input[name='from']")["value"]).to eq("2026-05-01")
    expect(parsed_html.at_css("input[name='to']")["value"]).to eq("2026-05-03")
  end

  it "supports one-sided confirmed_at filters and ignores invalid dates" do
    create(:read_confirmation, document:, user: create(:user, :external, name: "Earlier Reader"), confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Boundary Reader"), confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document:, user: create(:user, :external, name: "Later Reader"), confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, from: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(read_confirmation_rows.join).to include("Boundary Reader")
    expect(read_confirmation_rows.join).to include("Later Reader")
    expect(read_confirmation_rows.join).not_to include("Earlier Reader")

    get admin_read_confirmations_path(project_id: project.id, to: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(read_confirmation_rows.join).to include("Earlier Reader")
    expect(read_confirmation_rows.join).to include("Boundary Reader")
    expect(read_confirmation_rows.join).not_to include("Later Reader")

    get admin_read_confirmations_path(project_id: project.id, from: "not-a-date", to: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(read_confirmation_rows.join).to include("Earlier Reader")
    expect(read_confirmation_rows.join).to include("Boundary Reader")
    expect(read_confirmation_rows.join).not_to include("Later Reader")
  end

  it "shows an empty state when the document slug does not belong to the project" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, document_slug: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("指定した文書はこの案件に見つかりません。")
    expect(page_text).to include("既読確認はありません")
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("指定した文書URL識別子に一致する文書がないため、既読確認は表示されません。")
    expect(page_text).not_to include("部分一致で複数の文書が対象です。")
    expect(page_text).not_to include("Reader One / reader@example.com")
    expect(company_filter_options).not_to include("Client A")
    expect(user_filter_options).not_to include(a_string_including("Reader One"))
    expect(read_confirmation_rows).to be_empty
  end

  it "prompts for a project without leaking read confirmation rows when none is selected" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択すると既読確認の内訳を表示します。")
    expect(page_text).not_to include("Manual")
    expect(page_text).not_to include("Reader One / reader@example.com")
    expect(parsed_html.at_css("select[name='project_id']")).to be_present
    document_slug_input = parsed_html.at_css("input[name='document_slug'][type='search']")
    expect(document_slug_input).to be_present
    expect(document_slug_input["maxlength"]).to eq(Admin::ReadConfirmationsController::DOCUMENT_QUERY_MAX_LENGTH.to_s)
    expect(parsed_html.at_css("input[name='from'][type='date']")).to be_present
    expect(parsed_html.at_css("input[name='to'][type='date']")).to be_present
    expect(parsed_html.at_css("select[name='company_id']")).to be_present
    expect(parsed_html.at_css("select[name='user_id']")).to be_present
    expect(company_filter_options).not_to include("Client A")
    expect(user_filter_options).not_to include(a_string_including("Reader One"))
    expect(read_confirmation_rows).to be_empty
  end

  it "redirects CSV requests without a selected project instead of exporting all confirmations" do
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_read_confirmations_path(format: :csv)

    expect(response).to redirect_to(admin_read_confirmations_path)

    follow_redirect!

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("CSV出力には案件選択が必要です。")
    expect(page_text).not_to include("Manual")
    expect(page_text).not_to include("Reader One / reader@example.com")
  end

  it "exports CSV with the selected project, document, company, user, and date filters" do
    matching_reader = create(:user, :external, company:, name: "CSV Reader", email_address: "csv-reader@example.com")
    same_company_reader = create(:user, :external, company:, name: "Same Company Reader", email_address: "same-company-csv@example.com")
    other_company = create(:company, name: "Client B", domain: "client-b.example")
    other_company_reader = create(:user, :external, company: other_company, name: "Other Company Reader", email_address: "other-company-csv@example.com")
    other_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project: other_project, title: "Outside", slug: "outside")
    outside_reader = create(:user, :external, name: "Outside CSV Reader", email_address: "outside-csv@example.com")

    create(:read_confirmation, document:, user: matching_reader, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:read_confirmation, document:, user: same_company_reader, confirmed_at: Time.zone.local(2026, 5, 2, 13, 0, 0))
    create(:read_confirmation, document:, user: other_company_reader, confirmed_at: Time.zone.local(2026, 5, 2, 14, 0, 0))
    create(:read_confirmation, document: other_document, user: matching_reader, confirmed_at: Time.zone.local(2026, 5, 2, 15, 0, 0))
    create(:read_confirmation, document: outside_document, user: outside_reader, confirmed_at: Time.zone.local(2026, 5, 2, 16, 0, 0))

    sign_in_as(admin_user)

    get admin_read_confirmations_path(
      format: :csv,
      project_id: project.id,
      document_slug: document.slug,
      company_id: company.id,
      user_id: matching_reader.id,
      from: "2026-05-01",
      to: "2026-05-03"
    )

    csv = CSV.parse(response.body, headers: true)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv.headers).to eq(["確認日時", "文書名", "document slug", "確認者", "email", "会社"])
    expect(csv.size).to eq(1)
    expect(csv.first.to_h).to include(
      "文書名" => "Manual",
      "document slug" => "manual",
      "確認者" => "CSV Reader",
      "email" => "csv-reader@example.com",
      "会社" => "Client A"
    )
    expect(response.body).not_to include("Same Company Reader")
    expect(response.body).not_to include("Other Company Reader")
    expect(response.body).not_to include("Policy")
    expect(response.body).not_to include("Outside")
  end

  it "limits the selected project results to the latest 200 confirmations" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)

    201.times do |index|
      limited_document = create(:document, project:, title: "Limited Manual #{index}", slug: "limited-manual-#{index}")
      create(:read_confirmation, document: limited_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 200件")
    expect(read_confirmation_rows.size).to eq(200)
    expect(page_text).to include("Limited Manual 200")
    expect(page_text).to include("Limited Manual 1")
    expect(page_text).not_to include("Limited Manual 0")
  end

  it "paginates selected project results and exports only the current page" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)

    205.times do |index|
      paged_document = create(:document, project:, title: "Paged Manual #{index}", slug: "paged-manual-#{index}")
      create(:read_confirmation, document: paged_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, page: 2)

    page_two_rows = read_confirmation_rows.join

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 5件")
    expect(page_text).to include("表示範囲: 201-205件目")
    expect(page_text).to include("Page 2 / 2")
    expect(read_confirmation_rows.size).to eq(5)
    expect(page_two_rows).to include("Paged Manual 4")
    expect(page_two_rows).to include("Paged Manual 0")
    expect(page_two_rows).not_to include("Paged Manual 5")
    expect(page_two_rows).not_to include("Paged Manual 204")

    get admin_read_confirmations_path(project_id: project.id, page: 999)

    oversized_page_rows = read_confirmation_rows.join

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示範囲: 201-205件目")
    expect(page_text).to include("Page 2 / 2")
    expect(read_confirmation_rows.size).to eq(5)
    expect(oversized_page_rows).to include("Paged Manual 4")
    expect(oversized_page_rows).to include("Paged Manual 0")
    expect(oversized_page_rows).not_to include("Paged Manual 5")
    expect(oversized_page_rows).not_to include("Paged Manual 204")

    get admin_read_confirmations_path(project_id: project.id, page: 2, format: :csv)

    csv = CSV.parse(response.body, headers: true)
    csv_titles = csv.map { _1["文書名"] }
    csv_slugs = csv.map { _1["document slug"] }

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv.size).to eq(5)
    expect(csv_titles).to eq((0..4).to_a.reverse.map { "Paged Manual #{_1}" })
    expect(csv_slugs).to eq((0..4).to_a.reverse.map { "paged-manual-#{_1}" })
    expect(csv_titles).not_to include("Paged Manual 5")
    expect(csv_titles).not_to include("Paged Manual 204")
  end

  it "applies the latest 200 confirmation limit after the confirmed_at date filter" do
    base_time = Time.zone.local(2026, 5, 1, 9, 0, 0)
    create(:read_confirmation, document: create(:document, project:, title: "Outside Period Latest", slug: "outside-period-latest"), user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 9, 0, 0))

    201.times do |index|
      limited_document = create(:document, project:, title: "Period Manual #{index}", slug: "period-manual-#{index}")
      create(:read_confirmation, document: limited_document, user: viewer, confirmed_at: base_time + index.minutes)
    end

    sign_in_as(admin_user)

    get admin_read_confirmations_path(project_id: project.id, from: "2026-05-01", to: "2026-05-01")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 200件")
    expect(read_confirmation_rows.size).to eq(200)
    expect(page_text).to include("Period Manual 200")
    expect(page_text).to include("Period Manual 1")
    expect(page_text).not_to include("Period Manual 0")
    expect(page_text).not_to include("Outside Period Latest")
  end

  it "forbids external users and company master admins" do
    sign_in_as(external_user)
    get admin_read_confirmations_path(project_id: project.id)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(company_master_admin)
    get admin_read_confirmations_path(project_id: project.id)
    expect(response).to have_http_status(:forbidden)
  end
end
