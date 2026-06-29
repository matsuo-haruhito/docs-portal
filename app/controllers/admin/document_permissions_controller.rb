class Admin::DocumentPermissionsController < Admin::BaseController
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20

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

  def project_search
    render json: { options: document_permission_project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? document_permission_project_option(project) : nil }
  end

  def document_search
    render json: { options: document_permission_document_options(searchable_documents) }
  end

  def selected_document
    document = Document.includes(:project).find_by(id: params[:id])

    render json: { option: document ? document_permission_document_option(document) : nil }
  end

  private

  def set_document_permission
    @document_permission = DocumentPermission.find_by!(public_id: params[:public_id])
  end

  def load_index_resources
    @filters = filter_params
    @selected_project = Project.find_by(id: @filters[:project_id]) if @filters[:project_id].present?
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
    @companies = Company.order(:domain)
    @users = User.order(:email_address)
  end

  def document_permission_params
    permitted = params.require(:document_permission).permit(:document_id, :company_id, :user_id, :access_level)
    permitted[:company_id] = nil if permitted[:company_id].blank?
    permitted[:user_id] = nil if permitted[:user_id].blank?
    permitted
  end

  def searchable_projects
    scope = Project.order(:code, :id)
    query = normalize_project_search_query(params[:q])
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    term = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :term OR LOWER(projects.name) LIKE :term",
      term:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def normalize_project_search_query(value)
    value.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def document_permission_project_options(projects)
    projects.map { |project| document_permission_project_option(project) }
  end

  def document_permission_project_option(project)
    { value: project.id, text: helpers.document_permission_filter_project_label(project) }
  end

  def searchable_documents
    scope = Document.joins(:project).includes(:project).order("documents.title ASC", "documents.id ASC")
    query = params[:q].to_s.strip
    return scope.limit(20) if query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(documents.title) LIKE :term OR LOWER(documents.slug) LIKE :term OR LOWER(projects.name) LIKE :term",
      term:
    ).limit(20)
  end

  def document_permission_document_options(documents)
    documents.map { |document| document_permission_document_option(document) }
  end

  def document_permission_document_option(document)
    { value: document.id, text: "#{document.title} / #{document.project.name}" }
  end
end
