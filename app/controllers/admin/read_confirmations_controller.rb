require "csv"

class Admin::ReadConfirmationsController < Admin::BaseController
  before_action :require_admin_only!

  include Admin::BoundedProjectOptions

  DISPLAY_LIMIT = 200
  DOCUMENT_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  FILTER_CANDIDATE_LIMIT = 50
  FILTER_SEARCH_LIMIT = 20
  CSV_HEADERS = [
    "確認日時",
    "文書名",
    "document slug",
    "確認者",
    "email",
    "会社"
  ].freeze

  def index
    @selected_project = selected_read_confirmation_project
    @projects = bounded_project_options(@selected_project)
    @document_slug = document_slug_param
    @selected_user_id = params[:user_id].to_s.strip
    @selected_company_id = params[:company_id].to_s.strip
    @invalid_confirmed_date_params = []
    @confirmed_from = parsed_date_param(:from)
    @confirmed_to = parsed_date_param(:to)
    @invalid_confirmed_date_labels = @invalid_confirmed_date_params.map { confirmed_date_filter_label(_1) }
    @matching_documents = matching_documents if @selected_project
    @selected_document = @matching_documents.first if @matching_documents&.one?
    @selected_company = selected_company_filter
    @read_confirmation_companies = read_confirmation_company_candidates
    @selected_user = selected_user_filter
    @read_confirmation_users = read_confirmation_user_candidates
    @read_confirmations_scope = filtered_read_confirmations_scope
    @read_confirmations_total_count = @read_confirmations_scope.count
    @read_confirmations_total_pages = read_confirmations_total_pages
    @read_confirmations_page = read_confirmations_page_param
    @read_confirmations = paginated_read_confirmations
    @read_confirmations_page_start = read_confirmations_page_start
    @read_confirmations_page_end = read_confirmations_page_end
    @read_confirmations_csv_query = read_confirmations_csv_query
    @read_confirmations_previous_page_query = read_confirmations_page_query(@read_confirmations_page - 1) if @read_confirmations_page > 1
    @read_confirmations_next_page_query = read_confirmations_page_query(@read_confirmations_page + 1) if @read_confirmations_page < @read_confirmations_total_pages

    respond_to do |format|
      format.html
      format.csv do
        if @selected_project
          send_data read_confirmations_csv,
                    filename: read_confirmations_csv_filename,
                    type: "text/csv; charset=utf-8"
        else
          redirect_to admin_read_confirmations_path, alert: "CSV出力には案件選択が必要です。"
        end
      end
    end
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  def company_search
    render json: { options: read_confirmation_company_options(searchable_read_confirmation_companies) }
  end

  def selected_company
    company = selected_company_for_project(params[:id])

    render json: { option: company ? read_confirmation_company_option(company) : nil }
  end

  def user_search
    render json: { options: read_confirmation_user_options(searchable_read_confirmation_users) }
  end

  def selected_user
    user = selected_user_for_project(params[:id])

    render json: { option: user ? read_confirmation_user_option(user) : nil }
  end

  private

  def selected_read_confirmation_project
    return if params[:project_id].blank?

    Project.find_by(id: params[:project_id])
  end

  def searchable_projects
    scope = Project.order(:code, :id)
    query = normalize_project_search_query(params[:q])
    return scope.limit(PROJECT_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Project.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(projects.code) LIKE :pattern OR LOWER(projects.name) LIKE :pattern",
      pattern:
    ).limit(PROJECT_SEARCH_LIMIT)
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.read_confirmation_project_option_label(project) }
  end

  def document_slug_param
    params[:document_slug].to_s.strip.presence&.slice(0, DOCUMENT_QUERY_MAX_LENGTH)
  end

  def matching_documents
    return Document.none unless @selected_project
    return Document.none if @document_slug.blank?

    query = "%#{ActiveRecord::Base.sanitize_sql_like(@document_slug)}%"

    @selected_project
      .documents
      .where("documents.title LIKE :query OR documents.slug LIKE :query", query:)
      .order(:title, :slug, :id)
  end

  def document_filter_applied?
    @document_slug.present?
  end

  def document_filter_unmatched?
    document_filter_applied? && @matching_documents.blank?
  end

  def parsed_date_param(name)
    value = params[name].to_s.strip
    return if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    @invalid_confirmed_date_params << name
    nil
  end

  def confirmed_date_filter_label(name)
    case name.to_sym
    when :from
      "開始日"
    when :to
      "終了日"
    else
      name.to_s
    end
  end

  def normalized_read_confirmations_query
    query = request.query_parameters.to_h
    query.delete("format")
    @invalid_confirmed_date_params.each { |name| query.delete(name.to_s) }
    if @document_slug.present?
      query["document_slug"] = @document_slug
    else
      query.delete("document_slug")
    end
    query
  end

  def read_confirmations_csv_query
    read_confirmations_page_query(@read_confirmations_page).merge(format: :csv)
  end

  def read_confirmations_page_query(page)
    query = normalized_read_confirmations_query
    if page.to_i > 1
      query["page"] = page.to_i
    else
      query.delete("page")
    end
    query
  end

  def read_confirmation_company_scope
    project = @selected_project || Project.find_by(id: params[:project_id])
    return Company.none unless project

    Company
      .joins(users: { read_confirmations: :document })
      .where(documents: { project_id: project.id })
      .distinct
      .order(:name, :domain, :id)
  end

  def read_confirmation_company_candidates
    return Company.none if document_filter_unmatched?

    records = read_confirmation_company_scope.limit(FILTER_CANDIDATE_LIMIT).to_a
    return records if @selected_company.blank? || records.any? { _1.id == @selected_company.id }

    records + [@selected_company]
  end

  def selected_company_filter
    return if @selected_company_id.blank?
    return if document_filter_unmatched?

    selected_company_for_project(@selected_company_id)
  end

  def selected_company_for_project(company_id)
    return if company_id.blank?

    read_confirmation_company_scope.unscope(:order).find_by(id: company_id)
  end

  def read_confirmation_user_scope
    project = @selected_project || Project.find_by(id: params[:project_id])
    return User.none unless project

    scope = User
      .joins(read_confirmations: :document)
      .where(documents: { project_id: project.id })
    if params[:company_id].present?
      company = selected_company_for_project(params[:company_id])
      return User.none unless company

      scope = scope.where(company:)
    end
    scope
      .includes(:company)
      .distinct
      .order(:email_address, :id)
  end

  def scoped_read_confirmation_user_scope
    return User.none unless @selected_project
    return User.none if document_filter_unmatched?
    return User.none if @selected_company_id.present? && @selected_company.blank?

    scope = User
      .joins(read_confirmations: :document)
      .where(documents: { project_id: @selected_project.id })
    scope = scope.where(company: @selected_company) if @selected_company
    scope
      .includes(:company)
      .distinct
      .order(:email_address, :id)
  end

  def read_confirmation_user_candidates
    records = scoped_read_confirmation_user_scope.limit(FILTER_CANDIDATE_LIMIT).to_a
    return records if @selected_user.blank? || records.any? { _1.id == @selected_user.id }

    records + [@selected_user]
  end

  def selected_user_filter
    return if @selected_user_id.blank?

    scoped_read_confirmation_user_scope.unscope(:order).find_by(id: @selected_user_id)
  end

  def selected_user_for_project(user_id)
    return if user_id.blank?

    read_confirmation_user_scope.unscope(:order).find_by(id: user_id)
  end

  def searchable_read_confirmation_companies
    scope = read_confirmation_company_scope
    query = normalized_filter_query(params[:q])
    return scope.limit(FILTER_SEARCH_LIMIT) if query.blank?

    pattern = "%#{Company.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(companies.name) LIKE :pattern OR LOWER(companies.domain) LIKE :pattern",
      pattern:
    ).limit(FILTER_SEARCH_LIMIT)
  end

  def searchable_read_confirmation_users
    scope = read_confirmation_user_scope.left_joins(:company)
    query = normalized_filter_query(params[:q])
    return scope.limit(FILTER_SEARCH_LIMIT) if query.blank?

    pattern = "%#{User.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(users.name) LIKE :pattern OR LOWER(users.email_address) LIKE :pattern OR LOWER(companies.name) LIKE :pattern OR LOWER(companies.domain) LIKE :pattern",
      pattern:
    ).limit(FILTER_SEARCH_LIMIT)
  end

  def normalized_filter_query(value)
    value.to_s.strip.first(DOCUMENT_QUERY_MAX_LENGTH)
  end

  def read_confirmation_company_options(companies)
    companies.map { read_confirmation_company_option(_1) }
  end

  def read_confirmation_company_option(company)
    label = company.display_name
    label = "#{label} / #{company.domain}" if company.domain.present?

    { value: company.id, text: label }
  end

  def read_confirmation_user_options(users)
    users.map { read_confirmation_user_option(_1) }
  end

  def read_confirmation_user_option(user)
    { value: user.id, text: [user.display_name, user.email_address, user.company&.display_name].compact_blank.join(" / ") }
  end

  def filtered_read_confirmations_scope
    return ReadConfirmation.none unless @selected_project
    return ReadConfirmation.none if document_filter_unmatched?
    return ReadConfirmation.none if @selected_company_id.present? && @selected_company.blank?
    return ReadConfirmation.none if @selected_user_id.present? && @selected_user.blank?

    scope = ReadConfirmation
      .joins(:document)
      .where(documents: { project_id: @selected_project.id })
    scope = scope.where(documents: { id: @matching_documents.select(:id) }) if document_filter_applied?
    scope = scope.joins(user: :company).where(users: { company_id: @selected_company.id }) if @selected_company
    scope = scope.where(user: @selected_user) if @selected_user
    scope = scope.where("read_confirmations.confirmed_at >= ?", @confirmed_from.beginning_of_day) if @confirmed_from
    scope = scope.where("read_confirmations.confirmed_at <= ?", @confirmed_to.end_of_day) if @confirmed_to
    scope.includes(user: :company, document: :project)
      .order(confirmed_at: :desc, id: :desc)
  end

  def read_confirmations_total_pages
    [(@read_confirmations_total_count.to_f / DISPLAY_LIMIT).ceil, 1].max
  end

  def read_confirmations_page_param
    page = Integer(params[:page].to_s, exception: false)
    page = 1 if page.blank? || page <= 0
    [page, @read_confirmations_total_pages].min
  end

  def paginated_read_confirmations
    @read_confirmations_scope
      .offset((@read_confirmations_page - 1) * DISPLAY_LIMIT)
      .limit(DISPLAY_LIMIT)
  end

  def read_confirmations_page_start
    return 0 if @read_confirmations_total_count.zero?

    ((@read_confirmations_page - 1) * DISPLAY_LIMIT) + 1
  end

  def read_confirmations_page_end
    return 0 if @read_confirmations_total_count.zero?

    @read_confirmations_page_start + @read_confirmations.size - 1
  end

  def read_confirmations_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS

      @read_confirmations.each do |confirmation|
        csv << read_confirmation_csv_row(confirmation)
      end
    end
  end

  def read_confirmation_csv_row(confirmation)
    [
      confirmation.confirmed_at.strftime("%Y-%m-%d %H:%M:%S"),
      confirmation.document.title,
      confirmation.document.slug,
      confirmation.user.display_name,
      confirmation.user.email_address,
      confirmation.user.company&.display_name || "-"
    ]
  end

  def read_confirmations_csv_filename
    project_token = @selected_project.code.presence || @selected_project.public_id

    "read-confirmations-#{project_token}-#{Date.current.iso8601}.csv"
  end
end
