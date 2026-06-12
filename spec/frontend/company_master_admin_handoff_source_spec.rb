require "rails_helper"

RSpec.describe "Company master admin handoff source" do
  let(:controller_source) { Rails.root.join("app/frontend/controllers/company_master_admin_handoff_controller.js").read }
  let(:application_source) { Rails.root.join("app/frontend/entrypoints/application.js").read }
  let(:view_source) { Rails.root.join("app/views/admin/dashboard/company_master_admin.html.slim").read }

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
      expect(view_source).to include('pre.company-master-admin-handoff-template data-company-master-admin-handoff-target="template" tabindex="0"')
      expect(view_source).to include("連絡先や forbidden admin surface への direct link はここでは固定しません")
    end
  end

  it "keeps clipboard success, failure, and unsupported states explicit" do
    aggregate_failures do
      expect(controller_source).to include('static targets = ["template", "status"]')
      expect(controller_source).to include("event.preventDefault()")
      expect(controller_source).to include("navigator.clipboard?.writeText")
      expect(controller_source).to include("依頼テンプレートをコピーしました。")
      expect(controller_source).to include("コピー機能を使えません。テンプレートを選択してコピーしてください。")
      expect(controller_source).to include("コピーできませんでした。テンプレートを選択してコピーしてください。")
      expect(controller_source).to include("this.statusTarget.hidden = false")
      expect(controller_source).to include("this.templateTarget.textContent.trim()")
    end
  end
end
