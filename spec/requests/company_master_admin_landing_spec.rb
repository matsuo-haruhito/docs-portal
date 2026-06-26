require "rails_helper"

RSpec.describe "Company master admin landing", type: :request do
  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def action_targets
    parsed_html.css("a[href], form[action]").map { |node| node["href"] || node["action"] }
  end

  it "separates allowed company/user actions from internal admin handoff items" do
    company = create(:company, name: "Alpha", domain: "alpha.example.com")
    sign_in_as(create(:user, :external, :company_master_admin, company:))

    get admin_root_path

    handoff_section = parsed_html.css("section.card[data-controller='company-master-admin-handoff']").first
    copy_button = handoff_section.at_css("button[data-action='company-master-admin-handoff#copy']")
    copy_status = handoff_section.at_css("#company-master-admin-handoff-status[role='status'][aria-live='polite']")
    handoff_template = handoff_section.at_css("textarea.company-master-admin-handoff-template[data-company-master-admin-handoff-target='template']")
    handoff_categories = handoff_section.css("input[name='company_master_admin_handoff_category'][data-company-master-admin-handoff-target='category']")
    admin_decision_category = handoff_categories.find { |category| category["value"] == "admin_decision" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("company_master_admin が /admin から最初に確認する、会社・ユーザー管理専用の入口です")
    expect(page_text).to include("自社の会社情報とユーザーだけを管理できます")
    expect(page_text).to include("案件、文書、文書権限、監査ログ、利用状況は internal admin へ引き継いでください")
    expect(page_text).to include("ここから直接移動できるのは、会社管理者として操作できる次の 2 画面だけです")
    expect(page_text).to include("会社を管理")
    expect(page_text).to include("ユーザーを管理")
    expect(page_text).to include("次の項目は依頼前の確認リストです。この画面からは移動できず")
    expect(page_text).to include("案件・案件所属")
    expect(page_text).to include("文書・文書権限")
    expect(page_text).to include("運用確認")
    expect(page_text).to include("管理者判断")
    expect(page_text).to include("依頼テンプレート")
    expect(page_text).to include("分類選択、入力欄、コピー対象 textarea の順で内容を整えてから")
    expect(page_text).to include("選ぶ目安: 案件への参加、担当変更、役割追加を internal admin に頼むとき")
    expect(page_text).to include("選ぶ目安: 文書の閲覧範囲や公開権限を調整してほしいとき")
    expect(page_text).to include("選ぶ目安: ログ、利用状況、申請状態など事実確認を依頼するとき")
    expect(page_text).to include("選ぶ目安: 権限や所属会社の判断を company_master_admin だけで決められないとき")
    expect(page_text).to include("依頼テンプレートをコピー")
    expect(page_text).to include("【会社】Alpha")
    expect(page_text).to include("【対象ユーザー】名前 / メールアドレス")
    expect(page_text).to include("【分類】案件・案件所属")
    expect(page_text).to include("【確認項目】案件名、対象ユーザー、必要な役割、担当者変更の有無")
    expect(page_text).to include("【user type 変更相談】なし")
    expect(page_text).to include("会社管理者の権限や文書閲覧範囲を広げるものではありません")

    expect(copy_button["type"]).to eq("button")
    expect(copy_button["aria-describedby"]).to eq("company-master-admin-handoff-status")
    expect(copy_status.attribute("hidden")).to be_present
    expect(handoff_template["tabindex"]).to eq("0")
    expect(handoff_template.text).to include("【依頼内容】案件の作成、所属追加、担当者の付け替えなど")
    expect(handoff_categories.map { |category| category["data-category-label"] }).to contain_exactly(
      "案件・案件所属",
      "文書・文書権限",
      "運用確認",
      "管理者判断"
    )
    expect(handoff_categories.map { |category| category["data-request-hint"] }).to include(
      "案件の作成、所属追加、担当者の付け替えなど",
      "文書管理、閲覧範囲、文書公開権限の調整など",
      "監査ログ、利用状況、アクセス申請の確認など",
      "ユーザー種別の internal 化、他社ユーザーや他社会社の調整など"
    )
    expect(handoff_categories.map { |category| category["data-checklist-hint"] }).to include(
      "案件名、対象ユーザー、必要な役割、担当者変更の有無",
      "文書名、必要な閲覧範囲、公開権限、対象ユーザー",
      "確認したい期間、対象操作、アクセス申請の状態",
      "判断してほしい内容、関係する会社・ユーザー、業務背景"
    )
    expect(admin_decision_category["data-user-type-hint"]).to eq("あり")
    expect(handoff_categories.reject { |category| category == admin_decision_category }.map { |category| category["data-user-type-hint"] }).to all(eq("なし"))

    expect(action_targets).to include(admin_companies_path, admin_users_path)
    expect(action_targets).not_to include(
      admin_projects_path,
      admin_project_memberships_path,
      admin_documents_path,
      admin_document_permissions_path,
      admin_access_logs_path,
      admin_document_usage_reports_path
    )
    expect(action_targets).not_to include(a_string_starting_with("mailto:"))
  end

  it "keeps internal admins on the full admin entry instead of the company master admin landing" do
    sign_in_as(create(:user, :internal))

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(
      "管理画面",
      "モデル観測",
      "運用失敗入口",
      "基本マスタ",
      "関連設定"
    )
    expect(page_text).not_to include(
      "company_master_admin が /admin から最初に確認する、会社・ユーザー管理専用の入口です",
      "ここから直接移動できるのは、会社管理者として操作できる次の 2 画面だけです",
      "依頼テンプレートをコピー"
    )

    expect(action_targets).to include(
      admin_root_path,
      admin_projects_path,
      admin_project_memberships_path,
      admin_documents_path,
      admin_document_permissions_path,
      admin_access_logs_path,
      admin_document_usage_reports_path
    )
  end
end
