class DocumentBulkEditPlan
  Item = Data.define(:document, :before, :after, :changed_fields, :warnings, :errors) do
    def valid?
      errors.empty?
    end

    def changed?
      changed_fields.any?
    end
  end

  Summary = Data.define(:total_count, :changed_count, :unchanged_count, :valid_count, :invalid_count, :warning_count, :error_count, :target_document_ids) do
    def valid?
      invalid_count.zero? && error_count.zero?
    end
  end

  Result = Data.define(:documents, :changes, :items, :warnings, :errors) do
    def valid?
      errors.empty? && items.all?(&:valid?)
    end

    def summary
      Summary.new(
        total_count: items.size,
        changed_count: items.count(&:changed?),
        unchanged_count: items.count { !_1.changed? },
        valid_count: items.count(&:valid?),
        invalid_count: items.count { _1.errors.any? },
        warning_count: warnings.size + items.sum { _1.warnings.size },
        error_count: errors.size + items.sum { _1.errors.size },
        target_document_ids: documents.map(&:id)
      )
    end

    def serializable_summary
      summary.to_h
    end
  end

  def initialize(actor:, documents:, changes:)
    @actor = actor
    @documents = Array(documents)
    @changes = changes || {}
  end

  def call
    normalized = DocumentBulkEdit::ChangeNormalizer.new(
      actor:,
      documents:,
      raw_changes: changes
    ).call

    items = documents.map do |document|
      DocumentBulkEdit::ItemBuilder.new(
        document:,
        changes: normalized.changes,
        base_errors: normalized.errors,
        item_class: Item
      ).call
    end

    Result.new(
      documents:,
      changes: normalized.changes,
      items:,
      warnings: normalized.warnings,
      errors: normalized.errors
    )
  end

  private

  attr_reader :actor, :documents, :changes
end
