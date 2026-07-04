class Admin::ProjectTemplatesController < Admin::BaseController
  READ_ONLY_MAINTENANCE_ENV = "READ_ONLY_MAINTENANCE"

  before_action :require_admin_only!
  before_action :set_project

  def create
    if read_only_maintenance_mode?
      redirect_to edit_admin_project_path(@project), alert: project_template_maintenance_message
      return
    end

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

  def read_only_maintenance_mode?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(READ_ONLY_MAINTENANCE_ENV, nil))
  end

  def project_template_maintenance_message
    "メンテナンス中のため案件テンプレート適用は停止しています。案件一覧、編集内容、外部表示プレビュー、権限プレビューは確認できます。"
  end
end
