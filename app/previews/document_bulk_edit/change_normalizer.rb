module DocumentBulkEdit
  class ChangeNormalizer
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

    Result = Data.define(:changes, :warnings, :errors)

    def initialize(actor:, documents:, raw_changes:)
      @actor = actor
      @documents = Array(documents)
      @raw_changes = raw_changes || {}
    end

    def call
      errors = []
      warnings = []

      unless actor&.admin?
        errors << "bulk edit requires an admin actor"
        return Result.new(changes: empty_changes, warnings:, errors:)
      end

      if documents.empty?
        errors << "at least one document is required"
        return Result.new(changes: empty_changes, warnings:, errors:)
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

      normalized_changes = {
        document_attributes:,
        latest_version_attributes:,
        add_tag_names:,
        remove_tag_names:,
        archive: archive || false,
        restore: restore || false
      }

      errors << "at least one change is required" if no_requested_changes?(normalized_changes)
      if changes.key?(:data_classification_tag_names) || changes.key?(:add_data_classification_tag_names) || changes.key?(:remove_data_classification_tag_names)
        warnings << "data_classification_tags are not supported by the current schema and are excluded from this initial logic-only slice"
      end

      Result.new(changes: normalized_changes, warnings:, errors:)
    end

    private

    attr_reader :actor, :documents, :raw_changes

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
  end
end
