class DocumentBulkEditPreview
  Result = Data.define(:bulk_edit_dry_run, :plan) do
    delegate :summary, :valid?, to: :plan
  end

  DEFAULT_EXPIRATION = 1.day

  def initialize(actor:, documents:, changes:, expires_at: nil)
    @actor = actor
    @documents = Array(documents)
    @changes = changes || {}
    @expires_at = expires_at
  end

  def call
    plan = DocumentBulkEditPlan.new(actor:, documents:, changes:).call
    dry_run = BulkEditDryRun.create!(
      project: inferred_project,
      operation_type: :document_metadata,
      target_document_ids: documents.map(&:id),
      params_json: plan.changes,
      summary_json: { preview: plan.serializable_summary },
      result_json: { preview_items: serialize_items(plan.items) },
      warnings_json: plan.warnings + plan.items.flat_map(&:warnings),
      errors_json: plan.errors + plan.items.flat_map(&:errors),
      status: :analyzed,
      created_by: actor,
      expires_at: expires_at || DEFAULT_EXPIRATION.from_now
    )

    Result.new(bulk_edit_dry_run: dry_run, plan: plan)
  end

  private

  attr_reader :actor, :documents, :changes, :expires_at

  def inferred_project
    projects = documents.map(&:project).uniq
    projects.one? ? projects.first : nil
  end

  def serialize_items(items)
    items.map do |item|
      {
        document_id: item.document.id,
        document_public_id: item.document.public_id,
        before: item.before,
        after: item.after,
        changed_fields: item.changed_fields,
        warnings: item.warnings,
        errors: item.errors
      }
    end
  end
end
