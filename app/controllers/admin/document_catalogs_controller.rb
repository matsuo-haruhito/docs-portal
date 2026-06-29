class Admin::DocumentCatalogsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document_catalog, only: %i[edit update destroy]
  before_action :load_projects, only: %i[index create edit update]
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

  private

  def set_document_catalog
    @document_catalog = DocumentCatalog.find_by!(public_id: params[:public_id])
  end

  def load_projects
    @projects = Project.order(:code, :id)
  end

  def load_document_catalogs
    @document_catalogs = DocumentCatalog.includes(:project, :document_catalog_items).order("projects.code", :sort_order, :name, :id).references(:project)
  end

  def load_project_documents
    project_id = document_catalog_project_id
    @project_documents =
      if project_id.present?
        Document.where(project_id: project_id).includes(:latest_version).recommended_first
      elsif @document_catalog&.project_id.present?
        @document_catalog.project.documents.includes(:latest_version).recommended_first
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
end
