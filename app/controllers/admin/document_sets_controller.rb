class Admin::DocumentSetsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_document_set, only: %i[edit update destroy]
  before_action :load_projects, only: %i[index create edit update]
  before_action :load_document_sets, only: %i[index create]
  before_action :load_project_documents, only: %i[index create edit update]

  def index
    @document_set = DocumentSet.new(set_type: :delivery, visibility_policy: :restricted_external)
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

  private

  def set_document_set
    @document_set = DocumentSet.find_by!(public_id: params[:public_id])
  end

  def load_projects
    @projects = Project.order(:code)
  end

  def load_document_sets
    @document_sets = DocumentSet.includes(:project, document_set_items: %i[document document_version]).ordered
  end

  def load_project_documents
    project_id = document_set_project_id
    @project_documents =
      if project_id.present?
        Document.where(project_id: project_id).includes(:latest_version, :document_versions).recommended_first
      elsif @document_set&.project_id.present?
        @document_set.project.documents.includes(:latest_version, :document_versions).recommended_first
      else
        Document.none
      end
  end

  def document_set_project_id
    params.dig(:document_set, :project_id).presence || @document_set&.project_id
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
end
