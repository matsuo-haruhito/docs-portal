require "rails_helper"

RSpec.describe "Admin project template maintenance mode", type: :request do
  let(:admin) { User.create!(email: "admin@example.com", password: "password", role: :admin) }
  let(:project) { Project.create!(name: "Maintenance Project", code: "maintenance-project") }

  before do
    sign_in admin
  end

  describe "POST /admin/projects/:code/apply_template" do
    context "when READ_ONLY_MAINTENANCE is enabled" do
      around do |example|
        with_read_only_maintenance("true") { example.run }
      end

      it "redirects without applying the standard template" do
        applier = instance_double(ProjectTemplateApplier)

        allow(ProjectTemplateApplier).to receive(:new).and_return(applier)

        expect do
          post apply_template_admin_project_path(project.code)
        end.not_to change(Document, :count)

        expect(ProjectTemplateApplier).not_to have_received(:new)
        expect(response).to redirect_to(edit_admin_project_path(project.code))
        follow_redirect!
        expect(response.body).to include("メンテナンス中のため案件テンプレート適用は停止しています")
      end
    end

    context "when READ_ONLY_MAINTENANCE is disabled" do
      around do |example|
        with_read_only_maintenance(nil) { example.run }
      end

      it "keeps the existing template application behavior" do
        result = instance_double(ProjectTemplateApplier::Result, created_count: 2, skipped_count: 1)
        applier = instance_double(ProjectTemplateApplier, call: result)

        allow(ProjectTemplateApplier).to receive(:new).with(project: project).and_return(applier)

        post apply_template_admin_project_path(project.code)

        expect(applier).to have_received(:call)
        expect(response).to redirect_to(edit_admin_project_path(project.code))
        follow_redirect!
        expect(response.body).to include("標準テンプレートを適用しました。作成: 2件 / スキップ: 1件")
      end
    end
  end

  describe "read-only admin project surfaces" do
    around do |example|
      with_read_only_maintenance("true") { example.run }
    end

    it "keeps index, edit, external preview, and permission preview available" do
      project

      get admin_projects_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Maintenance Project")

      get edit_admin_project_path(project.code)
      expect(response).to have_http_status(:ok)

      get external_preview_admin_project_path(project.code)
      expect(response).to have_http_status(:ok)

      get permission_preview_admin_project_path(project.code)
      expect(response).to have_http_status(:ok)
    end
  end

  def with_read_only_maintenance(value)
    original = ENV.fetch("READ_ONLY_MAINTENANCE", nil)
    value.nil? ? ENV.delete("READ_ONLY_MAINTENANCE") : ENV["READ_ONLY_MAINTENANCE"] = value
    yield
  ensure
    original.nil? ? ENV.delete("READ_ONLY_MAINTENANCE") : ENV["READ_ONLY_MAINTENANCE"] = original
  end
end
