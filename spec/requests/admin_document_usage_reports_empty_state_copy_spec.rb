require "rails_helper"

RSpec.describe "Admin document usage report empty state copy", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "EMPTY", name: "Empty State Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def row_column_text(title, column_key)
    row = parsed_html.css("table tbody tr").find do |candidate|
      candidate.at_css("td[data-rails-table-preferences-column-key='title'] a")&.text&.squish == title
    end
    cell = row&.at_css("td[data-rails-table-preferences-column-key='#{column_key}']")

    cell&.xpath(".//text()")&.map { |node| node.text.squish }&.reject(&:empty?)&.join(" ")
  end

  it "separates a project with no documents from filter-only empty results" do
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("この案件には文書がありません")
    expect(page_text).to include("案件に文書が追加されると、利用状況、既読確認、監査ログへの入口をここで確認できます。")
    expect(page_text).to include("現在の利用状況は「すべて」、並び順は「タイトル順」です。")
    expect(parsed_html.css("table tbody tr")).to be_empty
  end

  it "explains that no used rows means no usage signal under the current filters" do
    create(:document, project:, title: "Quiet Manual", slug: "quiet-manual")
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, usage_filter: "used")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("利用ありの文書はありません")
    expect(page_text).to include("条件に一致する文書はありません。")
    expect(page_text).to include("閲覧・DL・既読確認のいずれかがある文書はありません。")
    expect(page_text).to include("検索語、期間、利用状況filterを見直してください。")
    expect(parsed_html.css("table tbody tr")).to be_empty
  end

  it "keeps unused empty results away from deletion or archive decisions" do
    used_document = create(:document, project:, title: "Used Manual", slug: "used-manual")
    create(:access_log, project:, document: used_document, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, usage_filter: "unused")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("期間内に未利用候補はありません")
    expect(page_text).to include("期間内に閲覧・DL・既読確認がない文書はありません。")
    expect(page_text).to include("未利用は削除・archive確定ではなく、現在条件でsignalがない候補です。")
    expect(page_text).to include("現在の利用状況は「未利用」、並び順は「タイトル順」です。")
    expect(parsed_html.css("table tbody tr")).to be_empty
  end

  it "calls out query-only empty results separately" do
    create(:document, project:, title: "Known Manual", slug: "known-manual")
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id, q: "missing")

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索語に一致する文書はありません")
    expect(page_text).to include("文書名または slug が検索語に一致する文書はありません。")
    expect(page_text).to include("現在の利用状況は「すべて」、並び順は「タイトル順」、検索語は「missing」です。")
    expect(parsed_html.css("table tbody tr")).to be_empty
  end

  it "keeps unused and read-confirmation-only row hints explicit" do
    unused_document = create(:document, project:, title: "Unused Manual", slug: "unused-manual")
    read_only_document = create(:document, project:, title: "Read Only Manual", slug: "read-only-manual")
    create(:read_confirmation, document: read_only_document, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))
    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(row_column_text("Unused Manual", "used")).to include("未利用", "削除・archive確定ではありません")
    expect(row_column_text("Read Only Manual", "used")).to include("既読のみ", "閲覧・DLはなく、既読確認の内訳を確認", "閲覧・downloadはありません")
    expect(row_column_text("Read Only Manual", "read_confirmation_count")).to include("1", "内訳へ")
    expect(row_column_text("Unused Manual", "read_confirmation_count")).to eq("0")
  end
end
