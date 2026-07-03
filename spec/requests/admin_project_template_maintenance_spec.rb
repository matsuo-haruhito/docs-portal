require "rails_helper"

RSpec.describe "Admin project template maintenance mode", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "TPL-MAINT", name: "Template Maintenance Project") }

  def with_read_only_maintenance(value)
    previous = ENV.fetch(Admin::ProjectTemplatesController::READ_ONLY_MAINTENANCE_ENV, nil)
    ENV[Admin::ProjectTemplatesController::READ_ONLY_MAINTENANCE_ENV] = value
    yield
  ensure
    if previous.nil?
      ENV.delete(Admin::ProjectTemplatesController::READ_ONLY_MAINTENANCE_ENV)
    else
      ENV[Admin::ProjectTemplatesController::READ_ONLY_MAINTENANCE_ENV] = previous
    end
  end

  it "does not apply the standard project template during read-only maintenance" do
    sign_in_as(admin_user)
    allow(ProjectTemplateApplier).to receive(:new)

    expect do
      with_read_only_maintenance("1") do
        post apply_template_admin_project_path(project.code)
      end
    end.not_to change(Document, :count)

    expect(ProjectTemplateApplier).not_to have_received(:new)
    expect(response).to redirect_to(edit_admin_project_path(project))
    expect(flash[:alert]).to include("メンテナンス中のため案件テンプレート適用は停止しています")
  end

  it "keeps project read-only screens available during read-only maintenance" do
    sign_in_as(admin_user)

    with_read_only_maintenance("true") do
      get admin_projects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(project.name)

      get edit_admin_project_path(project.code)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("標準文書テンプレート")

      get external_preview_admin_project_path(project.code)
      expect(response).to have_http_status(:ok)

      get permission_preview_admin_project_path(project.code)
      expect(response).to have_http_status(:ok)
    end
  end

  it "keeps template application available when read-only maintenance is disabled" do
    sign_in_as(admin_user)
    result = instance_double(ProjectTemplateApplier::Result, created_count: 2, skipped_count: 1)
    applier = instance_double(ProjectTemplateApplier, call: result)
    allow(ProjectTemplateApplier).to receive(:new).with(project:).and_return(applier)

    with_read_only_maintenance("0") do
      post apply_template_admin_project_path(project.code)
    end

    expect(ProjectTemplateApplier).to have_received(:new).with(project:)
    expect(applier).to have_received(:call)
    expect(response).to redirect_to(edit_admin_project_path(project))
    expect(flash[:notice]).to eq("標準テンプレートを適用しました。作成: 2件 / スキップ: 1件")
  end
end
