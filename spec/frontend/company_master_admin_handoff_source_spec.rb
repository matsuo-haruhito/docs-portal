require "rails_helper"

RSpec.describe "Company master admin handoff source" do
  let(:controller_source) { Rails.root.join("app/frontend/controllers/company_master_admin_handoff_controller.js").read }
  let(:application_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:view_source) { Rails.root.join("app/views/admin/dashboard/company_master_admin.html.slim").read }
  let(:nav_source) { Rails.root.join("app/views/admin/_nav.html.slim").read }
  let(:visual_check_note) { Rails.root.join("docs/qa/company_master_admin_handoff_visual_check.md").read }

  it "registers the handoff controller without adding entrypoint DOM setup" do
    aggregate_failures do
      expect(application_source).to include('import CompanyMasterAdminHandoffController from "../controllers/company_master_admin_handoff_controller"')
      expect(application_source).to include('application.register("company-master-admin-handoff", CompanyMasterAdminHandoffController)')
      expect(application_source).not_to include("querySelectorAll")
      expect(application_source).not_to include("addEventListener")
      expect(application_source).not_to include("new TomSelect")
    end
  end

  it "keeps the landing template copyable while preserving manual selection fallback" do
    aggregate_failures do
      expect(view_source).to include('section.card data-controller="company-master-admin-handoff"')
      expect(view_source).to include('button.button.secondary type="button" data-action="company-master-admin-handoff#copy"')
      expect(view_source).to include('span#company-master-admin-handoff-status.muted role="status" aria-live="polite" hidden=true data-company-master-admin-handoff-target="status"')
      expect(view_source).to include('textarea.company-master-admin-handoff-template rows="8" data-company-master-admin-handoff-target="template" tabindex="0"')
      expect(view_source).to include("連絡先や forbidden admin surface への direct link はここでは固定しません")
    end
  end

  it "keeps the company master admin navigation cues scoped to company and user management" do
    aggregate_failures do
      expect(nav_source).to include('li.nav-section.mt-2.small.fw-bold.text-muted.border-start.border-primary.ps-2.text-primary aria-current="location" aria-label="現在の領域: 会社・ユーザー管理" 会社・ユーザー管理')
      expect(nav_source).to include('company_master_nav_link.call("会社", admin_companies_path)')
      expect(nav_source).to include('company_master_nav_link.call("ユーザー", admin_users_path)')
      expect(view_source).to include('p = link_to "通常の案件一覧へ戻る", projects_path')
      expect(nav_source).not_to include('company_master_nav_link.call("案件"')
      expect(nav_source).not_to include('company_master_nav_link.call("監査ログ"')
    end
  end

  it "limits the handoff categories to the planned four classifications" do
    aggregate_failures do
      expect(view_source).to include('key: "project_membership", label: "案件・案件所属"')
      expect(view_source).to include('key: "document_permission", label: "文書・文書権限"')
      expect(view_source).to include('key: "operations", label: "運用確認"')
      expect(view_source).to include('key: "admin_decision", label: "管理者判断"')
      expect(view_source.scan("category_label:").size).to eq(1)
      expect(view_source).to include('action: "company-master-admin-handoff#selectCategory"')
    end
  end

  it "keeps category decision cues visible without changing the generated template data contract" do
    aggregate_failures do
      expect(view_source.scan("decision_hint:").size).to eq(4)
      expect(view_source).to include('span.muted = "選ぶ目安: #{category[:decision_hint]}"')
      expect(view_source).to include("分類選択、入力欄、コピー対象 textarea の順で内容を整えてから")
      expect(view_source).to include("選んだ分類の読み方")
      expect(view_source).to include("radio の選択に合わせて入力欄の初期値が切り替わり、下のコピー対象 textarea に反映されます")
      expect(view_source).not_to include("decision_hint: category[:decision_hint]")
      expect(controller_source).not_to include("decisionHint")
    end
  end

  it "keeps editable fields tied to the generated copy target" do
    aggregate_failures do
      expect(view_source).to include('data-company-master-admin-handoff-target="targetUser"')
      expect(view_source).to include('data-company-master-admin-handoff-target="requestDetail"')
      expect(view_source).to include('data-company-master-admin-handoff-target="checklist"')
      expect(view_source).to include('data-company-master-admin-handoff-target="userType"')
      expect(view_source).to include('data-company-master-admin-handoff-target="timeline"')
      expect(view_source.scan('data-action="input->company-master-admin-handoff#updateTemplate"').size).to eq(5)
      expect(view_source).to include("コピー対象 textarea は、選択中の分類と上の入力欄から生成されます")
      expect(view_source).to include("user type 変更相談が「あり」の分類は、会社管理者だけで権限や所属会社を判断せず")
      expect(view_source).to include("internal admin / human 判断待ちとして引き継いでください")
      expect(view_source).to include("この確認項目は依頼内容を整理するためのものであり、会社管理者の権限や文書閲覧範囲を広げるものではありません")
    end
  end

  it "keeps clipboard success, failure, and unsupported states explicit" do
    aggregate_failures do
      expect(controller_source).to include('static targets = ["template", "status", "category", "targetUser", "requestDetail", "checklist", "userType", "timeline"]')
      expect(controller_source).to include("event.preventDefault()")
      expect(controller_source).to include("navigator.clipboard?.writeText")
      expect(controller_source).to include("依頼テンプレートをコピーしました。")
      expect(controller_source).to include("コピー機能を使えません。テンプレートを選択してコピーしてください。")
      expect(controller_source).to include("コピーできませんでした。テンプレートを選択してコピーしてください。")
      expect(controller_source).to include("this.statusTarget.hidden = false")
      expect(controller_source).to include("this.templateTarget.value.trim()")
    end
  end

  it "generates template text from the selected category and editable fields" do
    aggregate_failures do
      expect(controller_source).to include("connect()")
      expect(controller_source).to include("selectCategory(event)")
      expect(controller_source).to include("applyCategoryHints(category)")
      expect(controller_source).to include("updateTemplate()")
      expect(controller_source).to include('`【分類】${this.selectedCategoryLabel}`')
      expect(controller_source).to include('`【対象ユーザー】${this.fieldValue("targetUser", "名前 / メールアドレス")}`')
      expect(controller_source).to include('`【確認項目】${this.fieldValue("checklist", "internal admin に確認してほしい項目")}`')
    end
  end

  it "keeps the QA checklist scoped as browser smoke guidance, not evidence by itself" do
    aggregate_failures do
      expect(visual_check_note).to include("company_master_admin 依頼テンプレート UI visual check")
      expect(visual_check_note).to include("Desktop viewport")
      expect(visual_check_note).to include("Narrow viewport")
      expect(visual_check_note).to include("4 分類")
      expect(visual_check_note).to include("copy status")
      expect(visual_check_note).to include("manual selection fallback")
      expect(visual_check_note).to include("clipboard success")
      expect(visual_check_note).to include("clipboard unsupported / failure")
      expect(visual_check_note).to include("実レンダリング結果の証跡は request spec で固定")
      expect(visual_check_note).to include("権限、保存 contract、依頼先連携、forbidden admin surface への direct link は変更しません")
      expect(visual_check_note).not_to include("mailto:")
    end
  end
end
