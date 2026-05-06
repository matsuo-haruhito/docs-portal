class DocumentBulkEditPlan
  DOCUMENT_ATTRIBUTE_KEYS = %i[
    category
    document_kind
    visibility_policy
    importance_level
    recommended_sort_order
    retention_until
    discard_candidate_at
  ].freeze

  LATEST_VERSION_ATTRIBUTE_KEYS = %i[
    snapshot_kind
    published_from
    published_until
  ].freeze

  SUPPORTED_CHANGE_KEYS = %i[
    document_attributes
    latest_version_attributes
    add_tag_names
    remove_tag_names
    archive
    restore
  ].freeze

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
    @raw_changes = changes || {}
  end

  def call
    errors = []
    warnings = []
    normalized_changes = normalize_changes(errors:, warnings:)

    items = documents.map do |document|
      build_item(document:, changes: normalized_changes, base_errors: errors)
    end

    Result.new(
      documents:,
      changes: normalized_changes,
      items:,
      warnings:,
      errors:
    )
  end

  private

  attr_reader :actor, :documents, :raw_changes

  def normalize_changes(errors:, warnings:)
    unless actor&.admin?
      errors << "bulk edit requires an admin actor"
      return empty_changes
    end

    if documents.empty?
      errors << "at least one document is required"
      return empty_changes
    end

    changes = raw_changes.to_h.deep_symbolize_keys
    unsupported_keys = changes.keys - SUPPORTED_CHANGE_KEYS
    errors.concat(unsupported_keys.map { "unsupported bulk edit key: #{_1}" })

    document_attributes = normalize_document_attributes(changes[:document_attributes], errors:)
    latest_version_attributes = normalize_latest_version_attributes(changes[:latest_version_attributes], errors:)
    add_tag_names = normalize_tag_names(changes[:add_tag_names], errors:, key: :add_tag_names)
    remove_tag_names = normalize_tag_names(changes[:remove_tag_names], errors:, key: :remove_tag_names)

    overlap = normalized_tag_overlap(add_tag_names, remove_tag_names)
    errors << "the same tag cannot be added and removed in one operation: #{overlap.join(', ')}" if overlap.any?

    archive = ActiveModel::Type::Boolean.new.cast(changes[:archive]) if changes.key?(:archive)
    restore = ActiveModel::Type::Boolean.new.cast(changes[:restore]) if changes.key?(:restore)
    errors << "archive and restore cannot both be requested" if archive && restore

    normalized = {
      document_attributes:,
      latest_version_attributes:,
      add_tag_names:,
      remove_tag_names:,
      archive: archive || false,
      restore: restore || false
    }

    errors << "at least one change is required" if no_requested_changes?(normalized)
    if changes.key?(:data_classification_tag_names) || changes.key?(:add_data_classification_tag_names) || changes.key?(:remove_data_classification_tag_names)
      warnings << "data_classification_tags are not supported by the current schema and are excluded from this initial logic-only slice"
    end

    normalized
  end

  def normalize_document_attributes(raw, errors:)
    attributes = raw.to_h.deep_symbolize_keys
    unsupported_keys = attributes.keys - DOCUMENT_ATTRIBUTE_KEYS
    errors.concat(unsupported_keys.map { "unsupported document attribute: #{_1}" })

    normalized = {}
    normalized[:category] = normalize_enum_value(Document, :categories, attributes[:category], errors:, label: :category) if attributes.key?(:category)
    normalized[:document_kind] = normalize_enum_value(Document, :document_kinds, attributes[:document_kind], errors:, label: :document_kind) if attributes.key?(:document_kind)
    normalized[:visibility_policy] = normalize_enum_value(Document, :visibility_policies, attributes[:visibility_policy], errors:, label: :visibility_policy) if attributes.key?(:visibility_policy)
    normalized[:importance_level] = normalize_enum_value(Document, :importance_levels, attributes[:importance_level], errors:, label: :importance_level) if attributes.key?(:importance_level)
    normalized[:recommended_sort_order] = normalize_non_negative_integer(attributes[:recommended_sort_order], errors:, label: :recommended_sort_order) if attributes.key?(:recommended_sort_order)
    normalized[:retention_until] = normalize_datetime(attributes[:retention_until], errors:, label: :retention_until) if attributes.key?(:retention_until)
    normalized[:discard_candidate_at] = normalize_datetime(attributes[:discard_candidate_at], errors:, label: :discard_candidate_at) if attributes.key?(:discard_candidate_at)
    normalized.compact
  end

  def normalize_latest_version_attributes(raw, errors:)
    attributes = raw.to_h.deep_symbolize_keys
    unsupported_keys = attributes.keys - LATEST_VERSION_ATTRIBUTE_KEYS
    errors.concat(unsupported_keys.map { "unsupported latest version attribute: #{_1}" })

    normalized = {}
    if attributes.key?(:snapshot_kind)
      value = attributes[:snapshot_kind].to_s.strip
      if value.blank? || DocumentVersion::SNAPSHOT_KINDS.exclude?(value)
        errors << "snapshot_kind is invalid"
      else
        normalized[:snapshot_kind] = value
      end
    end
    normalized[:published_from] = normalize_datetime(attributes[:published_from], errors:, label: :published_from) if attributes.key?(:published_from)
    normalized[:published_until] = normalize_datetime(attributes[:published_until], errors:, label: :published_until) if attributes.key?(:published_until)
    normalized.compact
  end

  def normalize_tag_names(raw, errors:, key:)
    return [] if raw.nil?
    unless raw.is_a?(Array)
      errors << "#{key} must be an array"
      return []
    end

    names = raw.filter_map do |value|
      name = value.to_s.strip
      name.presence
    end

    names.uniq { DocumentTag.normalize(_1) }
  end

  def normalized_tag_overlap(add_tag_names, remove_tag_names)
    add = add_tag_names.index_by { DocumentTag.normalize(_1) }
    remove = remove_tag_names.index_by { DocumentTag.normalize(_1) }
    add.keys & remove.keys
  end

  def normalize_enum_value(klass, mapping_method, raw_value, errors:, label:)
    value = raw_value.to_s.strip
    if value.blank? || klass.public_send(mapping_method).exclude?(value)
      errors << "#{label} is invalid"
      return
    end

    value
  end

  def normalize_non_negative_integer(raw_value, errors:, label:)
    value = ActiveModel::Type::Integer.new.cast(raw_value)
    if value.nil? || value.negative?
      errors << "#{label} must be a non-negative integer"
      return
    end

    value
  end

  def normalize_datetime(raw_value, errors:, label:)
    return if raw_value.nil? || raw_value == ""

    value = ActiveModel::Type::DateTime.new.cast(raw_value)
    if value.nil?
      errors << "#{label} is invalid"
      return
    end

    value
  end

  def no_requested_changes?(changes)
    changes[:document_attributes].blank? &&
      changes[:latest_version_attributes].blank? &&
      changes[:add_tag_names].blank? &&
      changes[:remove_tag_names].blank? &&
      !changes[:archive] &&
      !changes[:restore]
  end

  def empty_changes
    {
      document_attributes: {},
      latest_version_attributes: {},
      add_tag_names: [],
      remove_tag_names: [],
      archive: false,
      restore: false
    }
  end

  def build_item(document:, changes:, base_errors:)
    item_errors = base_errors.dup
    warnings = []
    before = serialize_document_state(document)
    after = deep_dup(before)

    apply_document_attribute_preview(after, changes[:document_attributes])
    apply_latest_version_attribute_preview(document, after, changes[:latest_version_attributes], item_errors)
    apply_tag_preview(document, after, changes[:add_tag_names], changes[:remove_tag_names], warnings)
    apply_archive_preview(document, after, changes[:archive], changes[:restore], warnings)
    validate_publication_window(after, item_errors)

    changed_fields = changed_fields_for(before:, after:)
    warnings << "no changes would be applied" if changed_fields.empty?

    Item.new(
      document:,
      before:,
      after:,
      changed_fields:,
      warnings:,
      errors: item_errors.uniq
    )
  end

  def serialize_document_state(document)
    {
      document: {
        id: document.id,
        public_id: document.public_id,
        title: document.title,
        slug: document.slug,
        project_id: document.project_id,
        category: document.category,
        document_kind: document.document_kind,
        visibility_policy: document.visibility_policy,
        importance_level: document.importance_level,
        recommended_sort_order: document.recommended_sort_order,
        retention_until: document.retention_until,
        discard_candidate_at: document.discard_candidate_at,
        archived: document.archived?
      },
      latest_version: serialize_latest_version_state(document.latest_version),
      tag_names: document.document_tags.order(:normalized_name).pluck(:name)
    }
  end

  def serialize_latest_version_state(version)
    return nil if version.blank?

    {
      id: version.id,
      public_id: version.public_id,
      snapshot_kind: version.snapshot_kind,
      published_from: version.published_from,
      published_until: version.published_until
    }
  end

  def apply_document_attribute_preview(after, attributes)
    attributes.each do |key, value|
      after[:document][key] = value
    end
  end

  def apply_latest_version_attribute_preview(document, after, attributes, errors)
    return if attributes.blank?

    if document.latest_version.blank?
      errors << "latest_version_attributes require a latest version"
      return
    end

    attributes.each do |key, value|
      after[:latest_version][key] = value
    end
  end

  def apply_tag_preview(document, after, add_tag_names, remove_tag_names, warnings)
    normalized_tags = document.document_tags.order(:normalized_name).pluck(:normalized_name, :name).to_h

    remove_tag_names.each do |name|
      normalized = DocumentTag.normalize(name)
      warnings << "tag not present and cannot be removed: #{name}" unless normalized_tags.key?(normalized)
      normalized_tags.delete(normalized)
    end

    add_tag_names.each do |name|
      normalized = DocumentTag.normalize(name)
      warnings << "tag already present: #{name}" if normalized_tags.key?(normalized)
      normalized_tags[normalized] = name
    end

    after[:tag_names] = normalized_tags.values.sort_by { DocumentTag.normalize(_1) }
  end

  def apply_archive_preview(document, after, archive, restore, warnings)
    return unless archive || restore

    if archive
      warnings << "document is already archived" if document.archived?
      after[:document][:archived] = true
    elsif restore
      warnings << "document is not archived" unless document.archived?
      after[:document][:archived] = false
    end
  end

  def validate_publication_window(after, errors)
    latest_version = after[:latest_version]
    return if latest_version.blank?
    return if latest_version[:published_from].blank? || latest_version[:published_until].blank?
    return if latest_version[:published_until] >= latest_version[:published_from]

    errors << "published_until must be after published_from"
  end

  def changed_fields_for(before:, after:)
    changed = []

    before[:document].each do |key, value|
      changed << key.to_s if value != after[:document][key]
    end

    if before[:latest_version] != after[:latest_version]
      before_latest = before[:latest_version] || {}
      after_latest = after[:latest_version] || {}
      (before_latest.keys | after_latest.keys).each do |key|
        next if before_latest[key] == after_latest[key]

        changed << "latest_version.#{key}"
      end
    end

    changed << "tag_names" if before[:tag_names] != after[:tag_names]
    changed
  end

  def deep_dup(value)
    Marshal.load(Marshal.dump(value))
  end
end
