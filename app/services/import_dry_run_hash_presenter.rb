class ImportDryRunHashPresenter
  def initialize(result)
    @result = result
  end

  def call
    {
      valid: result.valid?,
      summary: summary_hash,
      items: result.items.map { item_hash(_1) }
    }
  end

  private

  attr_reader :result

  def summary_hash
    summary = result.summary
    {
      valid: summary.valid?,
      total: summary.total,
      create_count: summary.create_count,
      update_count: summary.update_count,
      valid_count: summary.valid_count,
      invalid_count: summary.invalid_count,
      warning_count: summary.warning_count,
      error_count: summary.error_count,
      source_paths: summary.source_paths
    }
  end

  def item_hash(item)
    {
      valid: item.valid?,
      action: item.action,
      source_path: item.source_path,
      title: item.attributes[:title],
      attributes: item.attributes,
      warnings: item.warnings,
      errors: item.errors,
      matched_rules: item.matched_rules,
      existing_document_id: item.existing_document&.public_id
    }
  end
end
