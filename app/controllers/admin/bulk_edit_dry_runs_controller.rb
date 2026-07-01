class Admin::BulkEditDryRunsController < Admin::BaseController
  BULK_EDIT_CANDIDATE_LIMIT = 50
  BULK_EDIT_HANDOFF_RUNBOOK_PATH = "docs/文書マスタ運用runbook.md"
  LIFECYCLE_PURPOSES = %w[archive restore].freeze

  before_action :require_admin_only!
  before_action :set_bulk_edit_dry_run, only: %i[show update]

  def new
    @bulk_edit_dry_run = BulkEditDryRun.new(operation_type: :document_metadata)
    load_candidate_context
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
    load_candidate_context
    load_documents
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  rescue ActiveRecord::RecordInvalid => e
    @bulk_edit_dry_run = e.record
    load_candidate_context
    load_documents
    flash.now[:alert] = "一括編集dry-runを作成できませんでした。"
    render :new, status: :unprocessable_entity
  end

  def handoff
    selected_ids = normalized_integer_ids(params.dig(:bulk_edit, :document_ids))
    bounded_ids = selected_ids.first(BULK_EDIT_CANDIDATE_LIMIT)
    documents = documents_for_handoff(bounded_ids)

    render json: bulk_edit_handoff_payload(selected_ids:, bounded_ids:, documents:)
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
    @bulk_edit_dry_run = BulkEditDryRun.find_by!(public_id: params[:public_id] || params[:id])
  end

  def load_candidate_context
    @bulk_edit_candidate_source = params[:source].to_s == "admin_documents"
    @bulk_edit_candidate_limit = BULK_EDIT_CANDIDATE_LIMIT
    @bulk_edit_candidate_ids = permitted_candidate_document_ids
    @bulk_edit_candidate_filter_summaries = permitted_candidate_filter_summaries
    @bulk_edit_lifecycle_purpose = permitted_lifecycle_purpose
    @bulk_edit_candidate_document_ids = []
  end

  def load_documents
    scope = Document.joins(:project).includes(:project, :latest_version, :document_tags, :archived_by_user).order("projects.code", :title)
    @documents = @bulk_edit_candidate_source ? scope.where(id: @bulk_edit_candidate_ids) : scope
    @bulk_edit_candidate_document_ids = @bulk_edit_candidate_source ? @documents.map(&:id) : []
  end

  def permitted_candidate_document_ids
    normalized_integer_ids(params[:candidate_document_ids], limit: BULK_EDIT_CANDIDATE_LIMIT)
  end

  def permitted_candidate_filter_summaries
    Array(params[:source_filter_summaries]).filter_map do |value|
      value = value.to_s.strip
      next if value.blank?

      value.length > 80 ? "#{value.first(77)}..." : value
    end.first(7)
  end

  def permitted_lifecycle_purpose
    purpose = params[:lifecycle_purpose].to_s
    LIFECYCLE_PURPOSES.include?(purpose) ? purpose : nil
  end

  def normalized_integer_ids(values, limit: nil)
    ids = Array(values).filter_map do |value|
      Integer(value)
    rescue ArgumentError, TypeError
      nil
    end.uniq

    limit ? ids.first(limit) : ids
  end

  def documents_for_handoff(document_ids)
    documents_by_id = Document.includes(:project).where(id: document_ids).index_by(&:id)
    document_ids.filter_map { |document_id| documents_by_id[document_id] }
  end

  def bulk_edit_handoff_payload(selected_ids:, bounded_ids:, documents:)
    {
      source: bulk_edit_handoff_source,
      lifecycle_purpose: @bulk_edit_lifecycle_purpose,
      runbook_path: BULK_EDIT_HANDOFF_RUNBOOK_PATH,
      generated_at: Time.current.iso8601,
      limit: BULK_EDIT_CANDIDATE_LIMIT,
      candidate_count: permitted_candidate_document_ids.size,
      requested_selected_count: selected_ids.size,
      selected_count: documents.size,
      unresolved_selected_count: bounded_ids.size - documents.size,
      truncated: selected_ids.size > BULK_EDIT_CANDIDATE_LIMIT,
      source_filter_summaries: permitted_candidate_filter_summaries,
      documents: documents.map { |document| document_handoff_summary(document) }
    }
  end

  def bulk_edit_handoff_source
    params[:source].to_s == "admin_documents" ? "admin_documents" : "direct_selection"
  end

  def document_handoff_summary(document)
    {
      id: document.id,
      public_id: document.public_id,
      project: {
        code: document.project.code,
        name: document.project.name
      },
      title: document.title,
      status: document.archived? ? "archived" : "active"
    }
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
