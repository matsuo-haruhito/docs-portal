class Admin::BulkEditDryRunsController < Admin::BaseController
  before_action :require_admin_only!
  before_action :set_bulk_edit_dry_run, only: %i[show update]

  def new
    @bulk_edit_dry_run = BulkEditDryRun.new(operation_type: :document_metadata)
    load_documents
  end

  def create
    documents = selected_documents
    result = DocumentBulkEditPreview.new(
      actor: current_user,
      documents:,
      changes: bulk_edit_changes
    ).call

    redirect_to admin_bulk_edit_dry_run_path(result.bulk_edit_dry_run), notice: "一括編集dry-runを作成しました。"
  rescue ApplicationError::BadRequest => e
    @bulk_edit_dry_run = BulkEditDryRun.new(operation_type: :document_metadata)
    load_documents
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    @bulk_edit_dry_run = e.record
    load_documents
    flash.now[:alert] = "一括編集dry-runを作成できませんでした。"
    render :new, status: :unprocessable_entity
  end

  def show
    @preview_summary = summary_section(:preview)
    @execution_summary = summary_section(:execution)
    @preview_items = result_items(:preview_items)
    @execution_items = result_items(:execution_items)
  end

  def update
    DocumentBulkEditExecutor.new(dry_run: @bulk_edit_dry_run, actor: current_user).call
    redirect_to admin_bulk_edit_dry_run_path(@bulk_edit_dry_run), notice: "一括編集を実行しました。"
  rescue ApplicationError::BadRequest => e
    redirect_to admin_bulk_edit_dry_run_path(@bulk_edit_dry_run), alert: e.message
  end

  private

  def set_bulk_edit_dry_run
    @bulk_edit_dry_run = BulkEditDryRun.find_by!(public_id: params[:id])
  end

  def load_documents
    @documents = Document.joins(:project).includes(:project, :latest_version, :document_tags, :archived_by_user).order("projects.code", :title)
  end

  def selected_documents
    ids = Array(bulk_edit_params[:document_ids]).reject(&:blank?).map(&:to_i).uniq
    raise ApplicationError::BadRequest, "一括編集対象の文書を選択してください。" if ids.empty?

    Document.where(id: ids).includes(:project, :latest_version, :document_tags).to_a
  end

  def bulk_edit_params
    params.fetch(:bulk_edit, ActionController::Parameters.new).permit(
      :archive_action,
      document_ids: [],
      document_attributes: %i[category document_kind visibility_policy importance_level recommended_sort_order retention_until discard_candidate_at],
      latest_version_attributes: %i[snapshot_kind published_from published_until],
      tag_changes: %i[add_tag_names remove_tag_names]
    )
  end

  def bulk_edit_changes
    permitted = bulk_edit_params
    changes = {}
    document_attributes = compact_blank_values(permitted[:document_attributes])
    latest_version_attributes = compact_blank_values(permitted[:latest_version_attributes])
    tag_changes = permitted[:tag_changes] || {}

    changes[:document_attributes] = document_attributes if document_attributes.present?
    changes[:latest_version_attributes] = latest_version_attributes if latest_version_attributes.present?
    changes[:add_tag_names] = split_tag_names(tag_changes[:add_tag_names]) if tag_changes[:add_tag_names].present?
    changes[:remove_tag_names] = split_tag_names(tag_changes[:remove_tag_names]) if tag_changes[:remove_tag_names].present?

    case permitted[:archive_action]
    when "archive"
      changes[:archive] = true
    when "restore"
      changes[:restore] = true
    end

    changes
  end

  def compact_blank_values(value)
    value.to_h.filter_map do |key, raw_value|
      next if raw_value.blank?

      [key, raw_value]
    end.to_h
  end

  def split_tag_names(value)
    value.to_s.split(/[,、\n]/).map(&:strip).reject(&:blank?)
  end

  def summary_section(key)
    @bulk_edit_dry_run.summary_json[key.to_s] || @bulk_edit_dry_run.summary_json[key] || {}
  end

  def result_items(key)
    @bulk_edit_dry_run.result_json[key.to_s] || @bulk_edit_dry_run.result_json[key] || []
  end
end
