class Admin::DocumentPermissionsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document_permission, only: %i[edit update destroy]
  before_action :load_master_options, only: %i[index create edit update]

  def index
    @document_permission = DocumentPermission.new(access_level: :view)
    load_index_resources
  end

  def create
    @document_permission = DocumentPermission.new(document_permission_params)

    if @document_permission.save
      redirect_to admin_document_permissions_path, notice: "文書権限を登録しました。"
    else
      load_index_resources
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document_permission.update(document_permission_params)
      redirect_to admin_document_permissions_path, notice: "文書権限を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document_permission.destroy!
    redirect_to admin_document_permissions_path, notice: "文書権限を削除しました。"
  end

  private

  def set_document_permission
    @document_permission = DocumentPermission.find_by!(public_id: params[:public_id])
  end

  def load_index_resources
    @filters = filter_params
    @document_permissions_exist = DocumentPermission.exists?

    document_scope = filtered_document_scope
    permission_scope = filtered_permission_scope

    @document_permissions = permission_scope
      .joins(:document)
      .where(document_id: document_scope.select(:id))
      .includes(:document, :company, :user)
      .order("documents.title")
    @permission_overview_rows = DocumentPermissionOverview.new(document_scope, permission_scope:).rows
  end

  def filtered_document_scope
    scope = Document.all
    scope = scope.where(project_id: @filters[:project_id]) if @filters[:project_id].present?

    if @filters[:q].present?
      query = "%#{ActiveRecord::Base.sanitize_sql_like(@filters[:q])}%"
      scope = scope.where("documents.title LIKE :query OR documents.slug LIKE :query", query:)
    end

    if @filters[:access_level].present? || @filters[:target_type].present?
      scope = scope.where(id: filtered_permission_scope.select(:document_id))
    end

    scope
  end

  def filtered_permission_scope
    scope = DocumentPermission.all
    scope = scope.where(access_level: @filters[:access_level]) if @filters[:access_level].present?

    case @filters[:target_type]
    when "company"
      scope = scope.where.not(company_id: nil).where(user_id: nil)
    when "user"
      scope = scope.where(company_id: nil).where.not(user_id: nil)
    end

    scope
  end

  def filter_params
    permitted = params.permit(:project_id, :q, :access_level, :target_type).to_h.symbolize_keys
    permitted[:project_id] = nil unless permitted[:project_id].present? && Project.exists?(id: permitted[:project_id])
    permitted[:q] = permitted[:q].to_s.strip.presence
    permitted[:access_level] = nil unless DocumentPermission.access_levels.key?(permitted[:access_level])
    permitted[:target_type] = nil unless %w[company user].include?(permitted[:target_type])
    permitted
  end

  def load_master_options
    @documents = Document.includes(:project).order(:title)
    @companies = Company.order(:domain)
    @users = User.order(:email_address)
    @projects = Project.order(:name)
  end

  def document_permission_params
    permitted = params.require(:document_permission).permit(:document_id, :company_id, :user_id, :access_level)
    permitted[:company_id] = nil if permitted[:company_id].blank?
    permitted[:user_id] = nil if permitted[:user_id].blank?
    permitted
  end
end
