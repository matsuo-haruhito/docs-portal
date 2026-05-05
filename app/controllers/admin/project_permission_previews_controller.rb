class Admin::ProjectPermissionPreviewsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_project

  def show
    render json: PermissionChangePreviewHash.new(
      project: @project,
      viewers: preview_viewers,
      grant_document_ids: preview_params[:grant_document_ids],
      revoke_document_ids: preview_params[:revoke_document_ids],
      grant_download_document_ids: preview_params[:grant_download_document_ids],
      revoke_download_document_ids: preview_params[:revoke_download_document_ids],
      grant_project_membership: boolean_param(:grant_project_membership),
      revoke_project_membership: boolean_param(:revoke_project_membership)
    ).call
  end

  private

  def set_project
    @project = Project.find_by!(code: params[:id])
  end

  def preview_viewers
    ids = Array(preview_params[:user_ids]).map(&:to_i)
    company_ids = Array(preview_params[:company_ids]).map(&:to_i)

    User.active_only
      .includes(:company)
      .where(id: ids)
      .or(User.active_only.includes(:company).where(company_id: company_ids))
      .order(:email_address)
      .to_a
      .uniq(&:id)
  end

  def preview_params
    @preview_params ||= params.permit(
      :grant_project_membership,
      :revoke_project_membership,
      user_ids: [],
      company_ids: [],
      grant_document_ids: [],
      revoke_document_ids: [],
      grant_download_document_ids: [],
      revoke_download_document_ids: []
    )
  end

  def boolean_param(key)
    ActiveModel::Type::Boolean.new.cast(preview_params[key])
  end
end
