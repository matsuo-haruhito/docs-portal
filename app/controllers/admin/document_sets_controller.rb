require "csv"

class Admin::DocumentSetsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document_set, only: %i[edit update destroy]
  before_action :load_projects, only: %i[index create edit update]
  before_action :load_filters, only: %i[index create]
  before_action :load_document_sets, only: %i[index create]
  before_action :load_project_documents, only: %i[index create edit update]

  DOCUMENT_SET_QUERY_MAX_LENGTH = 100
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

  def document_search
    project = Project.find(params[:project_id])
    documents = project.documents.includes(:latest_version).recommended_first
    query = params[:q].to_s.strip

    if query.present?
      pattern = "%#{Document.sanitize_sql_like(query.downcase)}%"
      documents = documents.where("LOWER(title) LIKE :pattern OR LOWER(slug) LIKE :pattern", pattern: pattern)
    end

    payloads = documents.limit(20).map { |document| document_search_payload(document) }

    render json: {
      documents: payloads,
      options: payloads
    }
  end

  def document_version_search
    project = Project.find(params[:project_id])
    document = project.documents.find(params[:document_id])
    versions = document.document_versions.order(created_at: :desc, id: :desc)
    query = params[:q].to_s.strip

    if query.present?
      pattern = "%#{DocumentVersion.sanitize_sql_like(query.downcase)}%"
      versions = versions.where("LOWER(version_label) LIKE :pattern OR LOWER(status) LIKE :pattern", pattern: pattern)
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

  def load_projects
    @projects = Project.order(:code)
  end

  def load_filters
    @filters = document_set_filter_params
  end

  def load_document_sets
    scope = DocumentSet.includes(:project, document_set_items: %i[document document_version])
    scope = apply_enum_filter(scope, :set_type, DocumentSet.set_types)
    scope = apply_enum_filter(scope, :visibility_policy, DocumentSet.visibility_policies)
    scope = apply_query_filter(scope)
    @document_sets = scope.ordered
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

  def normalize_document_set_query(query)
    query.to_s.strip.first(DOCUMENT_SET_QUERY_MAX_LENGTH)
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
    scope.joins(:project).where(
      "LOWER(document_sets.name) LIKE :pattern OR LOWER(projects.name) LIKE :pattern OR LOWER(projects.code) LIKE :pattern",
      pattern: pattern
    )
  end

  def document_sets_csv
    CSV.generate(headers: true) do |csv|
      csv << CSV_HEADERS

      @document_sets.each do |document_set|
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

  def document_sets_csv_filename
    "document-sets-#{Date.current.iso8601}.csv"
  end
end
