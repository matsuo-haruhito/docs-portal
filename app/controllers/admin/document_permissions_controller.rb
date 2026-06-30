require "csv"

class Admin::DocumentPermissionsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document_permission, only: %i[edit update destroy]

  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  DOCUMENT_SEARCH_QUERY_MAX_LENGTH = 100
  DOCUMENT_SEARCH_LIMIT = 20
  COMPANY_SEARCH_QUERY_MAX_LENGTH = 100
  COMPANY_SEARCH_LIMIT = 20
  USER_SEARCH_QUERY_MAX_LENGTH = 100
  USER_SEARCH_LIMIT = 20
  DOCUMENT_PERMISSIONS_CSV_HEADERS = [
    "案件コード",
    "案件名",
    "文書名",
    "slug",
    "公開範囲",
    "付与先種別",
    "会社名",
    "会社domain",
    "ユーザー名",
    "ユーザーemail",
    "権限",
    "作成日時",
    "更新日時"
  ].freeze

  def index
    @document_permission = DocumentPermission.new(access_level: :view)
    load_index_resources

    respond_to do |format|
      format.html
      format.csv do
        send_data document_permissions_csv(@document_permissions),
          filename: "document-permissions-#{Time.zone.today.iso8601}.csv",
          type: "text/csv; charset=utf-8"
      end
    end
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

  def company_search
    render json: { options: document_permission_company_options(searchable_companies) }
  end

  def selected_company
    company = Company.find_by(id: params[:id])

    render json: { option: company ? document_permission_company_option(company) : nil }
  end

  def user_search
    render json: { options: document_permission_user_options(searchable_users) }
  end

  def selected_user
    user = User.find_by(id: params[:id])

    render json: { option: user ? document_permission_user_option(user) : nil }
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
      .includes({ document: :project }, :company, :user)
      .order("documents.title", "document_permissions.id")
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

  def document_permissions_csv(permissions)
    CSV.generate(headers: true) do |csv|
      csv << DOCUMENT_PERMISSIONS_CSV_HEADERS
      permissions.each do |permission|
        csv << document_permission_csv_row(permission)
      end
    end
  end

  def document_permission_csv_row(permission)
    document = permission.document
    project = document.project
    company = permission.company
    user = permission.user

    [
      project.code,
      project.name,
      document.title,
      document.slug,
      helpers.document_visibility_policy_label(document),
      document_permission_csv_target_type(permission),
      company&.name,
      company&.domain,
      user&.name,
      user&.email_address,
      helpers.document_permission_access_level_label(permission),
      permission.created_at.iso8601,
      permission.updated_at.iso8601
    ]
  end

  def document_permission_csv_target_type(permission)
    return helpers.document_permission_target_type_label("company") if permission.company_id.present?
    return helpers.document_permission_target_type_label("user") if permission.user_id.present?

    ""
  end

  def document_permission_params
    permitted = params.require(:document_permission).permit(:document_id, :company_id, :user_id, :access_level)
    permitted[:company_id] = nil if permitted[:company_id].blank?
    permitted[:user_id] = nil if permitted[:user_id].blank?
    permitted
  end

  def searchable_projects
    scope = Project.order(:code, :id)
    query = normalize_search_query(params[:q], PROJECT_SEARCH_QUERY_MAX_LENGTH)
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    term = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :term OR LOWER(projects.name) LIKE :term",
      term:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def searchable_documents
    scope = Document.joins(:project).includes(:project).order("documents.title ASC", "documents.id ASC")
    query = normalize_search_query(params[:q], DOCUMENT_SEARCH_QUERY_MAX_LENGTH)
    return scope.limit(DOCUMENT_SEARCH_LIMIT) if query.blank?

    term = "%#{ActiveRecord::Base.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(documents.title) LIKE :term OR LOWER(documents.slug) LIKE :term OR LOWER(projects.name) LIKE :term",
      term:
    ).limit(DOCUMENT_SEARCH_LIMIT)
  end

  def searchable_companies
    scope = Company.order(:domain, :id)
    query = normalize_search_query(params[:q], COMPANY_SEARCH_QUERY_MAX_LENGTH)
    return scope.limit(COMPANY_SEARCH_LIMIT) if query.blank?

    term = "%#{Company.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(companies.domain) LIKE :term OR LOWER(companies.name) LIKE :term",
      term:
    ).limit(COMPANY_SEARCH_LIMIT)
  end

  def searchable_users
    scope = User.order(:email_address, :id)
    query = normalize_search_query(params[:q], USER_SEARCH_QUERY_MAX_LENGTH)
    return scope.limit(USER_SEARCH_LIMIT) if query.blank?

    term = "%#{User.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(users.email_address) LIKE :term OR LOWER(users.name) LIKE :term",
      term:
    ).limit(USER_SEARCH_LIMIT)
  end

  def normalize_search_query(value, max_length)
    value.to_s.strip.first(max_length)
  end

  def document_permission_project_options(projects)
    projects.map { |project| document_permission_project_option(project) }
  end

  def document_permission_project_option(project)
    { value: project.id, text: helpers.document_permission_filter_project_label(project) }
  end

  def document_permission_document_options(documents)
    documents.map { |document| document_permission_document_option(document) }
  end

  def document_permission_document_option(document)
    { value: document.id, text: "#{document.title} / #{document.project.name}" }
  end

  def document_permission_company_options(companies)
    companies.map { |company| document_permission_company_option(company) }
  end

  def document_permission_company_option(company)
    { value: company.id, text: helpers.document_permission_form_company_label(company) }
  end

  def document_permission_user_options(users)
    users.map { |user| document_permission_user_option(user) }
  end

  def document_permission_user_option(user)
    { value: user.id, text: helpers.document_permission_form_user_label(user) }
  end
end
