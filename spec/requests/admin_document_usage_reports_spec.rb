require "rails_helper"
require "csv"

RSpec.describe "Admin document usage reports", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external) }
  let(:company_master_admin) { create(:user, :external, :company_master_admin) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def clear_link
    parsed_html.css("a[href='#{admin_document_usage_reports_path}']").find do |link|
      link.text.include?("条件をクリア")
    end
  end

  def selected_project_clear_link
    parsed_html.css("a[href='#{admin_document_usage_reports_path(project_id: project.id)}']").find do |link|
      link.text.include?("条件をクリア")
    end
  end

  def row_titles
    parsed_html.css("tbody td[data-rails-table-preferences-column-key='title']").map do |cell|
      cell.css("a").first.text.squish
    end
  end

  def row_column_text(title, column_key)
    row = parsed_html.css("table tbody tr").find do |candidate|
      candidate.at_css("td[data-rails-table-preferences-column-key='title'] a")&.text&.squish == title
    end
    cell = row&.at_css("td[data-rails-table-preferences-column-key='#{column_key}']")

    cell&.xpath(".//text()")&.map { |node| node.text.squish }&.reject(&:empty?)&.join(" ")
  end

  def table_preference_surfaces
    parsed_html.css(%([data-rails-table-preferences-table-key-value="admin_document_usage_reports"]))
  end

  def table_preference_table
    parsed_html.at_css(%(table[data-rails-table-preferences-table-key-value="admin_document_usage_reports"]))
  end

  def table_preference_columns_for(surface)
    JSON.parse(surface["data-rails-table-preferences-columns-value"])
  end

  def csv_rows
    CSV.parse(response.body, headers: true)
  end

  def audit_log_link(slug)
    parsed_html.at_css("a[href='#{admin_access_logs_path(project_id: project.id, document_q: slug)}']")
  end

  def summary_audit_log_link
    parsed_html.at_css("a[href='#{admin_access_logs_path(project_id: project.id)}']")
  end

  def read_confirmation_link(slug)
    parsed_html.at_css("a[href='#{admin_read_confirmations_path(project_id: project.id, document_slug: slug)}']")
  end

  def summary_read_confirmation_link
    parsed_html.at_css("a[href='#{admin_read_confirmations_path(project_id: project.id)}']")
  end

  def csv_export_link
    parsed_html.css("a").find { |link| link.text.squish == "CSV出力" }
  end

  it "shows selection controls and a prompt when no project is selected" do
    project
    sign_in_as(admin_user)

    get admin_document_usage_reports_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("文書利用状況")
    expect(page_text).to include("案件を選択すると集計結果を表示します。")

    form = parsed_html.at_css("form[action='#{admin_document_usage_reports_path}']")
    expect(form).to be_present
    expect(form.at_css("select[name='project_id']")).to be_present
    expect(form.at_css("input[name='q'][type='search']")).to be_present
    expect(form.at_css("select[name='usage_filter']")).to be_present
    expect(form.at_css("select[name='sort_order']")).to be_present
    expect(form.at_css("input[name='from'][type='date']")).to be_present
    expect(form.at_css("input[name='to'][type='date']")).to be_present

    option_texts = form.css("option").map { |option| option.text.squish }
    expect(option_texts).to include("選択してください", "すべて", "利用あり", "未利用", "タイトル順")
    expect(option_texts.any? { |text| text.include?("Usage Project") }).to be(true)

    expect(clear_link).to be_present
    expect(clear_link.text).to include("条件をクリア")
  end

  it "shows usage summary, selected project state, and document links for the selected project" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 11, 0, 0))
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Usage Project")
    expect(page_text).to include("USAGE")
    expect(page_text).to include("Manual")
    expect(page_text).to include("期間: 指定なし（案件全体の累積）")
    expect(page_text).to include("期間指定時は、閲覧・ダウンロード・既読確認・利用あり判定・最終アクセスを期間内の実績で集計します。")
    expect(page_text).to include("閲覧: 1")
    expect(page_text).to include("ダウンロード: 1")
    expect(page_text).to include("既読確認: 1")
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to match(/検索:\s*なし/)
    expect(page_text).to include("行内の「監査ログへ」は閲覧またはダウンロードがある文書だけに表示されます。")
    expect(page_text).to include("既読確認件数の「内訳へ」から確認者と確認時刻を追えます。")
    expect(page_text).to include("文書利用一覧の表示設定")

    selected_option = parsed_html.at_css("select[name='project_id'] option[selected]")
    expect(selected_option).to be_present
    expect(selected_option["value"]).to eq(project.id.to_s)
    expect(selected_option.text.squish).to include("Usage Project")

    expect(parsed_html.at_css("input[name='q'][type='search']")["value"]).to be_blank

    usage_filter_option = parsed_html.at_css("select[name='usage_filter'] option[selected]")
    expect(usage_filter_option).to be_present
    expect(usage_filter_option["value"]).to eq("all")

    sort_order_option = parsed_html.at_css("select[name='sort_order'] option[selected]")
    expect(sort_order_option).to be_present
    expect(sort_order_option["value"]).to eq("title")

    expect(parsed_html.at_css("input[name='from']")["value"]).to be_blank
    expect(parsed_html.at_css("input[name='to']")["value"]).to be_blank

    headers = parsed_html.css("table thead th").map { |header| header.text.squish }
    expect(headers).to include("文書名", "カテゴリ", "種別", "公開範囲", "利用", "閲覧", "ダウンロード", "既読確認", "最終アクセス")

    document_link = parsed_html.at_css("a[href='#{project_document_path(project, document.slug)}']")
    expect(document_link).to be_present
    expect(document_link.text).to eq("Manual")

    summary_link = summary_audit_log_link
    expect(summary_link).to be_present
    expect(summary_link.text).to eq("案件の監査ログへ")

    summary_confirmation_link = summary_read_confirmation_link
    expect(summary_confirmation_link).to be_present
    expect(summary_confirmation_link.text).to eq("案件の既読確認内訳へ")

    audit_log_document_link = audit_log_link(document.slug)
    expect(audit_log_document_link).to be_present
    expect(audit_log_document_link.text).to eq("監査ログへ")

    confirmation_document_link = read_confirmation_link(document.slug)
    expect(confirmation_document_link).to be_present
    expect(confirmation_document_link.text).to eq("内訳へ")

    expect(clear_link).to be_present
    expect(clear_link.text).to include("条件をクリア")

    expect(table_preference_surfaces.size).to eq(2)
    column_keys = table_preference_columns_for(table_preference_table).map { _1.fetch("key") }
    expect(column_keys).to include("title", "used", "read_confirmation_count", "last_accessed_at")
  end

  it "exports the selected project report as CSV and redirects CSV requests without a project" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 11, 0, 0))
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers["Content-Disposition"]).to include("document-usage-report-USAGE-")
    expect(csv_rows.headers).to eq(Admin::DocumentUsageReportsController::CSV_HEADERS)
    expect(csv_rows.size).to eq(1)
    expect(csv_rows.first.to_h).to include(
      "文書名" => "Manual",
      "slug" => "manual",
      "利用" => "利用あり",
      "閲覧" => "1",
      "ダウンロード" => "1",
      "既読確認" => "1"
    )

    get admin_document_usage_reports_path(format: :csv)

    expect(response).to redirect_to(admin_document_usage_reports_path)
    expect(flash[:alert]).to eq("CSV出力には案件選択が必要です。")
  end

  it "filters report rows by document title or slug and applies the same q to CSV" do
    title_match = create(:document, project:, title: "Onboarding Checklist", slug: "onboarding-checklist")
    slug_match = create(:document, project:, title: "Contract Guide", slug: "customer-contract")
    create(:document, project:, title: "Release Notes", slug: "release-notes")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, q: "boarding")

    expect(response).to have_http_status(:ok)
    expect(row_titles).to eq(["Onboarding Checklist"])
    expect(page_text).to include("表示中: 1件")
    expect(page_text).to match(/検索:\s*boarding/)
    expect(page_text).to include("CSV出力にも同じ検索条件を反映します。")
    expect(parsed_html.at_css("input[name='q'][type='search']")["value"]).to eq("boarding")
    expect(csv_export_link["href"]).to include("q=boarding")
    expect(csv_export_link["href"]).to include("format=csv")
    expect(audit_log_link(title_match.slug)).not_to be_present

    get admin_document_usage_reports_path(project_id: project.id, q: "CUSTOMER-CONTRACT")

    expect(response).to have_http_status(:ok)
    expect(row_titles).to eq(["Contract Guide"])
    expect(page_text).to match(/検索:\s*CUSTOMER-CONTRACT/)

    get admin_document_usage_reports_path(project_id: project.id, q: "boarding", format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(csv_rows.size).to eq(1)
    expect(csv_rows.first.to_h).to include("文書名" => "Onboarding Checklist", "slug" => title_match.slug)
    expect(csv_rows.map { _1["slug"] }).not_to include(slug_match.slug, "release-notes")
  end

  it "combines q with usage status, date range, and sorting as AND conditions" do
    in_range_old = create(:document, project:, title: "Report Alpha", slug: "report-alpha")
    in_range_new = create(:document, project:, title: "Report Beta", slug: "report-beta")
    out_of_range = create(:document, project:, title: "Report Gamma", slug: "report-gamma")
    unused_match = create(:document, project:, title: "Report Draft", slug: "report-draft")
    nonmatching = create(:document, project:, title: "Manual", slug: "manual")

    create(:access_log, project:, document: in_range_old, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document: in_range_new, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
    create(:access_log, project:, document: out_of_range, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 3, 10, 0, 0))
    create(:access_log, project:, document: nonmatching, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 11, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      q: "report",
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "2026-05-01",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("期間: 2026-05-01 から 2026-05-02 まで")
    expect(page_text).to include("表示中: 2件")
    expect(page_text).to match(/利用状況:\s*利用あり/)
    expect(page_text).to match(/検索:\s*report/)
    expect(row_titles).to eq(["Report Beta", "Report Alpha"])
    expect(row_titles).not_to include("Report Gamma", "Report Draft", "Manual")
    expect(audit_log_link(in_range_new.slug)).to be_present
    expect(audit_log_link(in_range_old.slug)).to be_present
    expect(audit_log_link(out_of_range.slug)).not_to be_present
    expect(audit_log_link(unused_match.slug)).not_to be_present
  end

  it "filters rows by usage status and sorts last_accessed rows before nil values" do
    newest_document = create(:document, project:, title: "Guide", slug: "guide")
    read_only_document = create(:document, project:, title: "Policy", slug: "policy")
    unused_document = create(:document, project:, title: "Checklist", slug: "checklist")

    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document: newest_document, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
    create(:read_confirmation, document: read_only_document, user: viewer, confirmed_at: Time.zone.local(2026, 5, 3, 10, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, usage_filter: "used", sort_order: "last_accessed_desc")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 3件")
    expect(page_text).to match(/利用状況:\s*利用あり/)
    expect(page_text).to match(/並び順:\s*最終アクセスが新しい順/)
    expect(page_text).to include("既読確認件数の「内訳へ」から確認者と確認時刻を追えます。")
    expect(row_titles).to eq(["Guide", "Manual", "Policy"])
    expect(row_titles).not_to include("Checklist")
    expect(row_column_text("Policy", "used")).to include("既読のみ", "既読確認の内訳を確認")
    expect(summary_audit_log_link).to be_present
    expect(summary_read_confirmation_link).to be_present
    expect(audit_log_link(newest_document.slug)).to be_present
    expect(audit_log_link(document.slug)).to be_present
    expect(audit_log_link(read_only_document.slug)).not_to be_present
    expect(audit_log_link(unused_document.slug)).not_to be_present
    expect(read_confirmation_link(read_only_document.slug)).to be_present
    expect(read_confirmation_link(unused_document.slug)).not_to be_present

    usage_filter_option = parsed_html.at_css("select[name='usage_filter'] option[selected]")
    expect(usage_filter_option).to be_present
    expect(usage_filter_option["value"]).to eq("used")

    sort_order_option = parsed_html.at_css("select[name='sort_order'] option[selected]")
    expect(sort_order_option).to be_present
    expect(sort_order_option["value"]).to eq("last_accessed_desc")
  end

  it "applies the date range to usage counts, used filtering, and last access sorting" do
    newest_document = create(:document, project:, title: "Guide", slug: "guide")
    read_only_document = create(:document, project:, title: "Policy", slug: "policy")
    outside_document = create(:document, project:, title: "Checklist", slug: "checklist")

    create(:access_log, project:, document:, user: viewer, company:, action_type: :download, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document: newest_document, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))
    create(:read_confirmation, document: read_only_document, user: viewer, confirmed_at: Time.zone.local(2026, 5, 2, 12, 0, 0))
    create(:access_log, project:, document: outside_document, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 3, 10, 0, 0))
    create(:read_confirmation, document: outside_document, user: viewer, confirmed_at: Time.zone.local(2026, 5, 3, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(
      project_id: project.id,
      usage_filter: "used",
      sort_order: "last_accessed_desc",
      from: "2026-05-01",
      to: "2026-05-02"
    )

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("期間: 2026-05-01 から 2026-05-02 まで")
    expect(page_text).to include("閲覧: 1")
    expect(page_text).to include("ダウンロード: 1")
    expect(page_text).to include("既読確認: 1")
    expect(page_text).to include("表示中: 3件")
    expect(row_titles).to eq(["Guide", "Manual", "Policy"])
    expect(row_titles).not_to include("Checklist")
    expect(parsed_html.at_css("input[name='from']")["value"]).to eq("2026-05-01")
    expect(parsed_html.at_css("input[name='to']")["value"]).to eq("2026-05-02")
    expect(summary_audit_log_link).to be_present
    expect(audit_log_link(newest_document.slug)).to be_present
    expect(audit_log_link(document.slug)).to be_present
    expect(audit_log_link(read_only_document.slug)).not_to be_present
    expect(audit_log_link(outside_document.slug)).not_to be_present
  end

  it "treats documents with only out-of-range activity as unused for the selected period" do
    outside_document = create(:document, project:, title: "Checklist", slug: "checklist")

    create(:access_log, project:, document: outside_document, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 4, 30, 10, 0, 0))
    create(:read_confirmation, document: outside_document, user: viewer, confirmed_at: Time.zone.local(2026, 4, 30, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, usage_filter: "unused", from: "2026-05-01", to: "2026-05-02")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("期間: 2026-05-01 から 2026-05-02 まで")
    expect(page_text).to include("表示中: 1件")
    expect(row_titles).to eq(["Checklist"])
    expect(audit_log_link(outside_document.slug)).not_to be_present
  end

  it "ignores invalid date inputs without returning an error" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 2, 10, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, from: "not-a-date", to: "2026-05-01")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("期間: 2026-05-01 まで")
    expect(page_text).to include("閲覧: 1")
    expect(parsed_html.at_css("input[name='from']")["value"]).to be_blank
    expect(parsed_html.at_css("input[name='to']")["value"]).to eq("2026-05-01")
  end

  it "falls back to default filter options when unknown filter params are provided" do
    unused_document = create(:document, project:, title: "Checklist", slug: "checklist")
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, usage_filter: "archived", sort_order: "updated_desc")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 2件")
    expect(page_text).to match(/利用状況:\s*すべて/)
    expect(page_text).to match(/並び順:\s*タイトル順/)
    expect(row_titles).to include("Manual", "Checklist")

    usage_filter_option = parsed_html.at_css("select[name='usage_filter'] option[selected]")
    expect(usage_filter_option).to be_present
    expect(usage_filter_option["value"]).to eq("all")

    sort_order_option = parsed_html.at_css("select[name='sort_order'] option[selected]")
    expect(sort_order_option).to be_present
    expect(sort_order_option["value"]).to eq("title")
    expect(audit_log_link(document.slug)).to be_present
    expect(audit_log_link(unused_document.slug)).not_to be_present
  end

  it "returns to the project selection state when project_id does not match a readable project" do
    project
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: "999999", usage_filter: "used", sort_order: "last_accessed_desc", q: "manual")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("案件を選択すると集計結果を表示します。")
    expect(page_text).not_to include("集計サマリ")
    expect(page_text).not_to include("文書利用一覧の表示設定")
    expect(parsed_html.css("table tbody tr")).to be_empty

    selected_project_option = parsed_html.at_css("select[name='project_id'] option[selected]")
    expect(selected_project_option).to be_nil

    usage_filter_option = parsed_html.at_css("select[name='usage_filter'] option[selected]")
    expect(usage_filter_option).to be_present
    expect(usage_filter_option["value"]).to eq("used")

    sort_order_option = parsed_html.at_css("select[name='sort_order'] option[selected]")
    expect(sort_order_option).to be_present
    expect(sort_order_option["value"]).to eq("last_accessed_desc")
    expect(parsed_html.at_css("input[name='q'][type='search']")["value"]).to eq("manual")
    expect(clear_link).to be_present
  end

  it "shows an empty-state message when the selected filter has no matching rows" do
    create(:document, project:, title: "Checklist", slug: "checklist")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, usage_filter: "used")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("条件に一致する文書はありません")
    expect(page_text).to include("現在の利用状況は「利用あり」、並び順は「タイトル順」です。")
    expect(page_text).to include("条件を変えるか、クリアして案件全体を確認してください。")
    expect(page_text).not_to include("文書利用一覧の表示設定")
    expect(summary_audit_log_link).to be_present
    expect(summary_read_confirmation_link).to be_present
    expect(selected_project_clear_link).to be_present
    expect(parsed_html.css("table tbody tr")).to be_empty
  end

  it "shows the active query in the empty-state message when q removes all rows" do
    create(:document, project:, title: "Checklist", slug: "checklist")

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, q: "missing", usage_filter: "unused")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 0件")
    expect(page_text).to include("条件に一致する文書はありません")
    expect(page_text).to include("現在の利用状況は「未利用」、並び順は「タイトル順」、検索語は「missing」です。")
    expect(page_text).to include("条件を変えるか、クリアして案件全体を確認してください。")
    expect(selected_project_clear_link).to be_present
    expect(parsed_html.css("table tbody tr")).to be_empty
  end

  it "forbids external users and company master admins" do
    sign_in_as(external_user)
    get admin_document_usage_reports_path
    expect(response).to have_http_status(:forbidden)

    sign_in_as(company_master_admin)
    get admin_document_usage_reports_path
    expect(response).to have_http_status(:forbidden)
  end
end
