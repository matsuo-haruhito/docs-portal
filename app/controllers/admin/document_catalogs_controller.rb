class Admin::DocumentCatalogsController < Admin::BaseController
  PROJECT_SEARCH_QUERY_MAX_LENGTH = 100
  PROJECT_SEARCH_LIMIT = 20
  DOCUMENT_SEARCH_QUERY_MAX_LENGTH = 100
  DOCUMENT_SEARCH_LIMIT = 20

  before_action :require_admin_only!
  before_action :set_document_catalog, only: %i[edit update destroy]
  before_action :load_document_catalogs, only: %i[index create]
  before_action :load_project_documents, only: %i[index create edit update]

  def index
    @document_catalog = DocumentCatalog.new(audience_type: :customer, visibility_policy: :restricted_external, sort_order: 0)
  end

  def create
    @document_catalog = DocumentCatalog.new(document_catalog_params)

    if save_document_catalog(@document_catalog)
      redirect_to admin_document_catalogs_path, notice: "文書カタログを登録しました。"
    else
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    @document_catalog.assign_attributes(document_catalog_params)

    if save_document_catalog(@document_catalog)
      redirect_to admin_document_catalogs_path, notice: "文書カタログを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document_catalog.destroy!
    redirect_to admin_document_catalogs_path, notice: "文書カタログを削除しました。"
  end

  def project_search
    render json: { options: project_options(searchable_projects) }
  end

  def selected_project
    project = Project.find_by(id: params[:id])

    render json: { option: project ? project_option(project) : nil }
  end

  def document_search
    project = Project.find_by(id: params[:project_id])
    payloads = project ? document_search_payloads(searchable_project_documents(project)) : []

    render json: {
      documents: payloads,
      options: payloads
    }
  end

  def selected_document
    project = Project.find_by(id: params[:project_id])
    document = project&.documents&.includes(:latest_version)&.find_by(id: params[:id])

    render json: { option: document ? document_search_payload(document) : nil }
  end

  private

  def set_document_catalog
    @document_catalog = DocumentCatalog.find_by!(public_id: params[:public_id])
  end

  def load_document_catalogs
    @document_catalogs = DocumentCatalog.includes(:project, :document_catalog_items).order("projects.code", :sort_order, :name, :id).references(:project)
  end

  def load_project_documents
    project_id = document_catalog_project_id
    project = Project.find_by(id: project_id)

    @project_documents =
      if project.present?
        visible_project_documents(project)
      else
        Document.none
      end
  end

  def document_catalog_project_id
    params.dig(:document_catalog, :project_id).presence || @document_catalog&.project_id
  end

  def document_catalog_params
    params.require(:document_catalog).permit(:project_id, :name, :description, :audience_type, :visibility_policy, :sort_order)
  end

  def save_document_catalog(document_catalog)
    ActiveRecord::Base.transaction do
      document_catalog.save!
      sync_items!(document_catalog)
    end

    true
  rescue ActiveRecord::RecordInvalid
    load_document_catalogs if action_name == "create"
    false
  end

  def sync_items!(document_catalog)
    rows = params.fetch(:document_catalog_items, {}).values
    normalized_rows = rows.filter_map do |row|
      next unless ActiveModel::Type::Boolean.new.cast(row[:selected])

      document = document_catalog.project.documents.find_by(id: row[:document_id])
      next if document.blank?

      {
        document: document,
        sort_order: row[:sort_order].presence || 0,
        note: row[:note].to_s
      }
    end

    document_catalog.document_catalog_items.destroy_all

    normalized_rows.each do |row|
      document_catalog.document_catalog_items.create!(
        document: row[:document],
        sort_order: row[:sort_order],
        note: row[:note]
      )
    end
  rescue ActiveRecord::RecordInvalid => e
    document_catalog.errors.add(:base, e.record.errors.full_messages.join(", "))
    raise
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

  def project_options(projects)
    projects.map { |project| project_option(project) }
  end

  def project_option(project)
    { value: project.id, text: helpers.document_catalog_project_option_label(project) }
  end

  def searchable_project_documents(project)
    documents = project.documents.includes(:latest_version).recommended_first
    query = normalize_document_search_query(params[:q])

    if query.present?
      pattern = "%#{Document.sanitize_sql_like(query.downcase)}%"
      documents = documents.where("LOWER(title) LIKE :pattern OR LOWER(slug) LIKE :pattern", pattern:)
    end

    documents.limit(DOCUMENT_SEARCH_LIMIT)
  end

  def visible_project_documents(project)
    documents = project.documents.includes(:latest_version).recommended_first
    selected_ids = document_catalog_selected_document_ids(project)
    selected_documents = selected_ids.present? ? documents.where(id: selected_ids).to_a : []
    bounded_documents = documents.limit(DOCUMENT_SEARCH_LIMIT).to_a

    (selected_documents + bounded_documents).uniq(&:id)
  end

  def document_catalog_selected_document_ids(project)
    if params[:document_catalog_items].present?
      item_rows = params[:document_catalog_items].respond_to?(:to_unsafe_h) ? params[:document_catalog_items].to_unsafe_h.values : params[:document_catalog_items].to_h.values

      return item_rows.filter_map do |row|
        next unless ActiveModel::Type::Boolean.new.cast(row[:selected] || row["selected"])

        row[:document_id] || row["document_id"]
      end
    end

    return [] if @document_catalog.blank? || @document_catalog.project_id != project.id

    @document_catalog.document_catalog_items.pluck(:document_id)
  end

  def document_search_payloads(documents)
    documents.map { |document| document_search_payload(document) }
  end

  def document_search_payload(document)
    {
      id: document.id,
      title: document.title,
      slug: document.slug,
      text: "#{document.title} (#{document.slug})",
      latest_version_label: document.latest_version&.version_label,
      path: project_document_path(document.project, document.slug)
    }
  end

  def normalize_project_search_query(query)
    query.to_s.strip.first(PROJECT_SEARCH_QUERY_MAX_LENGTH)
  end

  def normalize_document_search_query(query)
    query.to_s.strip.first(DOCUMENT_SEARCH_QUERY_MAX_LENGTH)
  end
end
