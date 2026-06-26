require "csv"

class Admin::DocumentSetsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document_set, only: %i[edit update destroy]
  before_action :load_filters, only: %i[index create]
  before_action :load_document_sets, only: %i[index create]
  before_action :load_project_documents, only: %i[index create edit update]

  DOCUMENT_SET_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  DOCUMENT_SEARCH_QUERY_MAX_LENGTH = 100
  DOCUMENT_SEARCH_LIMIT = 20
  DOCUMENT_VERSION_SEARCH_QUERY_MAX_LENGTH = 100
  DOCUMENT_VERSION_SEARCH_LIMIT = 20
  CSV_HEADERS = [
    "案件コード",
    "案件名",
    "文書セット名",
    "種別",
    "公開範囲",
    "文書数",
    "public_id"
  ].freeze

  def index
    @document_set = DocumentSet.new(set_type: :delivery, visibility_policy: :restricted_external)

    respond_to do |format|
      format.html
      format.csv do
        send_data document_sets_csv,
                  filename: document_sets_csv_filename,
                  type: "text/csv; charset=utf-8"
      end
      format.json do
        render json: document_sets_export_metadata
      end
    end
  end

  def create
    @document_set = DocumentSet.new(document_set_params)
    @document_set.created_by = current_user

    if save_document_set(@document_set)
      redirect_to admin_document_sets_path, notice: "文書セットを登録しました。"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @document_set.assign_attributes(document_set_params)

    if save_document_set(@document_set)
      redirect_to admin_document_sets_path, notice: "文書セットを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document_set.destroy!
    redirect_to admin_document_sets_path, notice: "文書セットを削除しました。"
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  def document_search
    project = Project.find(params[:project_id])
    documents = project.documents.includes(:latest_version).recommended_first
    query = normalize_document_search_query(params[:q])

    if query.present?
      pattern = "%#{Document.sanitize_sql_like(query.downcase)}%"
      documents = documents.where("LOWER(title) LIKE :pattern OR LOWER(slug) LIKE :pattern", pattern: pattern)
    end

    payloads = documents.limit(DOCUMENT_SEARCH_LIMIT).map { |document| document_search_payload(document) }

    render json: {
      documents: payloads,
      options: payloads
    }
  end

  def document_version_search
    project = Project.find(params[:project_id])
    document = project.documents.find(params[:document_id])
    versions = document.document_versions.order(created_at: :desc, id: :desc)
    query = normalize_document_version_search_query(params[:q])

    if query.present?
      pattern = "%#{DocumentVersion.sanitize_sql_like(query.downcase)}%"
      versions = versions.where("LOWER(version_label) LIKE :pattern", pattern: pattern)
    end

    payloads = versions.limit(DOCUMENT_VERSION_SEARCH_LIMIT).map { |version| document_version_search_payload(version) }

    render json: {
      versions: payloads,
      options: payloads
    }
  end

  private

  def set_document_set
    @document_set = DocumentSet.find_by!(public_id: params[:public_id])
  end

  def load_filters
    @filters = document_set_filter_params
  end

  def load_document_sets
    document_scope = filtered_document_sets
    @document_sets_filtered_count = document_scope.count
    ordered_document_sets = document_scope.includes(:project, document_set_items: %i[document document_version]).ordered
    @document_sets, @document_sets_pagination = paginate_admin_list(ordered_document_sets, @document_sets_filtered_count)
    @document_set_page_params = document_set_page_params
  end

  def filtered_document_sets
    scope = DocumentSet.joins(:project)
    scope = apply_enum_filter(scope, :set_type, DocumentSet.set_types)
    scope = apply_enum_filter(scope, :visibility_policy, DocumentSet.visibility_policies)
    scope = apply_query_filter(scope)
    scope.distinct
  end

  def document_set_page_params
    page_params = @filters.transform_keys(&:to_s)
    page_params["per_page"] = @document_sets_pagination[:per_page] if params[:per_page].present?
    page_params.reject { |_key, value| value.blank? }
  end

  def load_project_documents
    project_id = document_set_project_id
    @project_documents =
      if project_id.present?
        Document.where(project_id: project_id).includes(:latest_version).recommended_first
      elsif @document_set&.project_id.present?
        @document_set.project.documents.includes(:latest_version).recommended_first
      else
        Document.none
      end
  end

  def document_set_project_id
    params.dig(:document_set, :project_id).presence || @document_set&.project_id
  end

  def document_set_filter_params
    params.to_unsafe_h.symbolize_keys.slice(:set_type, :visibility_policy, :q).tap do |filters|
      filters[:q] = normalize_document_set_query(filters[:q]) if filters.key?(:q)
    end
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

  def normalize_document_set_query(query)
    query.to_s.strip.first(DOCUMENT_SET_QUERY_MAX_LENGTH)
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def normalize_document_search_query(query)
    query.to_s.strip.first(DOCUMENT_SEARCH_QUERY_MAX_LENGTH)
  end

  def normalize_document_version_search_query(query)
    query.to_s.strip.first(DOCUMENT_VERSION_SEARCH_QUERY_MAX_LENGTH)
  end

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.document_set_project_option_label(project) }
  end

  def document_set_params
    params.require(:document_set).permit(:project_id, :name, :description, :set_type, :visibility_policy, :sort_order)
  end

  def save_document_set(document_set)
    ActiveRecord::Base.transaction do
      document_set.save!
      sync_items!(document_set)
    end

    true
  rescue ActiveRecord::RecordInvalid
    load_document_sets if action_name == "create"
    false
  end

  def sync_items!(document_set)
    rows = params.fetch(:document_set_items, {}).values
    normalized_rows = rows.filter_map do |row|
      next unless ActiveModel::Type::Boolean.new.cast(row[:selected])

      document = document_set.project.documents.find_by(id: row[:document_id])
      next if document.blank?

      version = if row[:document_version_id].present?
        document.document_versions.find_by(id: row[:document_version_id])
      end

      {
        document:,
        document_version: version,
        sort_order: row[:sort_order].presence || 0,
        note: row[:note].to_s
      }
    end

    document_set.document_set_items.destroy_all

    normalized_rows.each do |row|
      document_set.document_set_items.create!(
        document: row[:document],
        document_version: row[:document_version],
        sort_order: row[:sort_order],
        note: row[:note]
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    document_set.errors.add(:base, e.record.errors.full_messages.join(", "))
    raise
  end

  def document_search_payload(document)
    {
      id: document.id,
      title: document.title,
      slug: document.slug,
      text: "#{document.title} (#{document.slug})",
      latest_version_label: document.latest_version&.version_label
    }
  end

  def document_version_search_payload(version)
    label = helpers.document_version_label(version)
    status_label = helpers.document_version_status_label(version)

    {
      id: version.id,
      version_label: version.version_label,
      status: version.status,
      text: "#{label} (#{status_label})"
    }
  end

  def apply_enum_filter(scope, key, enum_values)
    value = @filters[key].to_s
    return scope if value.blank? || !enum_values.key?(value)

    scope.where(key => value)
  end

  def apply_query_filter(scope)
    query = @filters[:q].to_s
    return scope if query.blank?

    pattern = "%#{DocumentSet.sanitize_sql_like(query.downcase)}%"
    scope.where(
      "LOWER(document_sets.name) LIKE :pattern OR LOWER(projects.name) LIKE :pattern OR LOWER(projects.code) LIKE :pattern",
      pattern: pattern
    )
  end

  def document_sets_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS

      filtered_document_sets.includes(:project, document_set_items: %i[document document_version]).ordered.each do |document_set|
        csv << document_set_csv_row(document_set)
      end
    end
  end

  def document_set_csv_row(document_set)
    [
      document_set.project.code,
      document_set.project.name,
      document_set.name,
      helpers.document_set_type_label(document_set),
      helpers.document_set_visibility_policy_label(document_set),
      document_set.document_set_items.size,
      document_set.public_id
    ]
  end

  def document_sets_export_metadata
    {
      exported_at: Time.current.iso8601,
      report_type: "document_sets",
      export_scope: "current_filters",
      description: "文書セットCSVの条件確認用metadataです。CSV本体の行データではありません。",
      filters: document_sets_metadata_filters,
      ignored_filters: document_sets_metadata_ignored_filters,
      row_count: @document_sets_filtered_count,
      csv_headers: CSV_HEADERS,
      summary: {
        matching_document_sets: @document_sets_filtered_count,
        filter_labels: helpers.admin_document_set_filter_labels(@filters),
        csv_filename: document_sets_csv_filename,
        csv_columns_fixed: true
      }
    }
  end

  def document_sets_metadata_filters
    filters = {}
    query = @filters[:q].to_s
    filters[:q] = { value: query } if query.present?

    set_type = metadata_enum_filter(:set_type, DocumentSet.set_types)
    filters[:set_type] = set_type if set_type.present?

    visibility_policy = metadata_enum_filter(:visibility_policy, DocumentSet.visibility_policies)
    filters[:visibility_policy] = visibility_policy if visibility_policy.present?

    filters
  end

  def metadata_enum_filter(key, enum_values)
    value = @filters[key].to_s
    return nil if value.blank? || !enum_values.key?(value)

    label = case key
    when :set_type
      helpers.document_set_type_label(value)
    when :visibility_policy
      helpers.document_set_visibility_policy_label(value)
    end

    { value: value, label: label }
  end

  def document_sets_metadata_ignored_filters
    ignored_filters = {}
    ignored_filters[:set_type] = @filters[:set_type].to_s if unsupported_enum_filter?(:set_type, DocumentSet.set_types)
    ignored_filters[:visibility_policy] = @filters[:visibility_policy].to_s if unsupported_enum_filter?(:visibility_policy, DocumentSet.visibility_policies)
    ignored_filters
  end

  def unsupported_enum_filter?(key, enum_values)
    value = @filters[key].to_s
    value.present? && !enum_values.key?(value)
  end

  def document_sets_csv_filename
    "document-sets-#{Date.current.iso8601}.csv"
  end
end
