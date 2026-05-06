class DocumentBulkEditExecutor
  Item = Data.define(:document_id, :document_public_id, :title, :status, :changed_fields, :warnings, :errors) do
    def success?
      status == :success
    end

    def failed?
      status == :failed
    end

    def skipped?
      status == :skipped
    end
  end

  Result = Data.define(:bulk_edit_dry_run, :plan, :items) do
    def success_count
      items.count(&:success?)
    end

    def failure_count
      items.count(&:failed?)
    end

    def skipped_count
      items.count(&:skipped?)
    end

    def summary
      {
        total_count: items.size,
        success_count:,
        failure_count:,
        skipped_count:
      }
    end
  end

  def initialize(dry_run:, actor:)
    @dry_run = dry_run
    @actor = actor
  end

  def call
    raise ApplicationError::Forbidden unless actor&.admin?
    raise ApplicationError::BadRequest, "bulk edit dry-run is expired" if dry_run.expired?
    raise ApplicationError::BadRequest, "bulk edit dry-run operation type is unsupported" unless dry_run.document_metadata?

    documents = Document.where(id: dry_run.document_ids).includes(:latest_version, :document_tags, :project).to_a
    plan = DocumentBulkEditPlan.new(actor:, documents:, changes: dry_run.params_json).call
    items = build_missing_document_items(documents) + plan.items.map { execute_item(_1, plan.changes) }

    update_dry_run!(plan:, items:)
    create_audit_log!(items:)
    Result.new(bulk_edit_dry_run: dry_run, plan:, items:)
  end

  private

  attr_reader :dry_run, :actor

  def build_missing_document_items(documents)
    existing_ids = documents.map(&:id)

    (dry_run.document_ids - existing_ids).map do |document_id|
      Item.new(
        document_id:,
        document_public_id: nil,
        title: nil,
        status: :failed,
        changed_fields: [],
        warnings: [],
        errors: ["document no longer exists"]
      )
    end
  end

  def execute_item(plan_item, normalized_changes)
    document = plan_item.document

    if plan_item.errors.any?
      return result_item_for(document:, status: :failed, changed_fields: plan_item.changed_fields, warnings: plan_item.warnings, errors: plan_item.errors)
    end

    unless plan_item.changed?
      return result_item_for(document:, status: :skipped, changed_fields: [], warnings: plan_item.warnings, errors: [])
    end

    ActiveRecord::Base.transaction do
      apply_document_attributes(document, normalized_changes[:document_attributes])
      apply_latest_version_attributes(document.latest_version, normalized_changes[:latest_version_attributes])
      apply_tag_names(document, normalized_changes[:add_tag_names], normalized_changes[:remove_tag_names])
      apply_archive_state(document, normalized_changes[:archive], normalized_changes[:restore])
    end

    result_item_for(document:, status: :success, changed_fields: plan_item.changed_fields, warnings: plan_item.warnings, errors: [])
  rescue StandardError => e
    result_item_for(document:, status: :failed, changed_fields: plan_item.changed_fields, warnings: plan_item.warnings, errors: [e.message])
  end

  def apply_document_attributes(document, attributes)
    return if attributes.blank?

    document.assign_attributes(attributes)
    document.save! if document.changed?
  end

  def apply_latest_version_attributes(version, attributes)
    return if version.blank? || attributes.blank?

    version.assign_attributes(attributes)
    version.save! if version.changed?
  end

  def apply_tag_names(document, add_tag_names, remove_tag_names)
    return if add_tag_names.blank? && remove_tag_names.blank?

    remove_tag_names.each do |name|
      normalized = DocumentTag.normalize(name)
      tag = DocumentTag.find_by(normalized_name: normalized)
      next if tag.blank?

      document.document_taggings.where(document_tag: tag).delete_all
    end

    add_tag_names.each do |name|
      normalized = DocumentTag.normalize(name)
      tag = DocumentTag.find_or_create_by!(normalized_name: normalized) do |record|
        record.name = name
      end
      document.document_taggings.find_or_create_by!(document_tag: tag) do |tagging|
        tagging.sort_order = document.document_taggings.count
      end
    end
  end

  def apply_archive_state(document, archive, restore)
    return unless archive || restore

    document.archive!(actor:) if archive && !document.archived?
    document.restore!(actor:) if restore && document.archived?
  end

  def result_item_for(document:, status:, changed_fields:, warnings:, errors:)
    Item.new(
      document_id: document.id,
      document_public_id: document.public_id,
      title: document.title,
      status:,
      changed_fields:,
      warnings:,
      errors:
    )
  end

  def update_dry_run!(plan:, items:)
    preview_summary = dry_run.summary_json["preview"] || dry_run.summary_json[:preview] || dry_run.summary_json
    preview_items = dry_run.result_json["preview_items"] || dry_run.result_json[:preview_items] || []
    execution_summary = Result.new(bulk_edit_dry_run: dry_run, plan:, items:).summary
    execution_errors = plan.errors + items.flat_map(&:errors)
    execution_warnings = plan.warnings + items.flat_map(&:warnings)

    dry_run.update!(
      summary_json: {
        preview: preview_summary,
        execution: execution_summary
      },
      result_json: {
        preview_items: preview_items,
        execution_items: items.map(&:to_h)
      },
      warnings_json: execution_warnings,
      errors_json: execution_errors,
      confirmed_by: actor,
      confirmed_at: Time.current,
      status: items.any?(&:success?) ? :confirmed : :failed
    )
  end

  def create_audit_log!(items:)
    summary = Result.new(bulk_edit_dry_run: dry_run, plan: nil, items:).summary
    AccessLog.create!(
      action_type: :bulk_edit,
      user: actor,
      company: actor.company,
      project: dry_run.project,
      target_type: "BulkEditDryRun",
      target_name: "#{dry_run.public_id} total=#{summary[:total_count]} success=#{summary[:success_count]} failed=#{summary[:failure_count]}",
      accessed_at: Time.current,
      ip_address: nil,
      user_agent: "system:document_bulk_edit_executor"
    )
  end
end
