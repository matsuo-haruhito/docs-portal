class Admin::ProjectTemplatesController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project

  def create
    result = ProjectTemplateApplier.new(project: @project).call

    redirect_to edit_admin_project_path(@project), notice: notice_message(result)
  end

  private

  def set_project
    @project = Project.find_by!(code: project_code_param)
  end

  def project_code_param
    params[:code] || params[:project_code] || params[:id] || params[:project_id]
  end

  def notice_message(result)
    "標準テンプレートを適用しました。作成: #{result.created_count}件 / スキップ: #{result.skipped_count}件"
  end
end