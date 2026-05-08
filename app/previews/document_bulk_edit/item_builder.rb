module DocumentBulkEdit
  class ItemBuilder
    def initialize(document:, changes:, base_errors:, item_class:)
      @document = document
      @changes = changes
      @base_errors = base_errors
      @item_class = item_class
    end

    def call
      item_errors = base_errors.dup
      warnings = []
      before = StateSerializer.new(document).call
      after = deep_dup(before)

      apply_document_attribute_preview(after, changes[:document_attributes])
      apply_latest_version_attribute_preview(after, changes[:latest_version_attributes], item_errors)
      apply_tag_preview(after, changes[:add_tag_names], changes[:remove_tag_names], warnings)
      apply_archive_preview(after, changes[:archive], changes[:restore], warnings)
      validate_publication_window(after, item_errors)

      changed_fields = changed_fields_for(before:, after:)
      warnings << "no changes would be applied" if changed_fields.empty?

      item_class.new(
        document:,
        before:,
        after:,
        changed_fields:,
        warnings:,
        errors: item_errors.uniq
      )
    end

    private

    attr_reader :document, :changes, :base_errors, :item_class

    def apply_document_attribute_preview(after, attributes)
      attributes.each do |key, value|
        after[:document][key] = value
      end
    end

    def apply_latest_version_attribute_preview(after, attributes, errors)
      return if attributes.blank?

      if document.latest_version.blank?
        errors << "latest_version_attributes require a latest version"
        return
      end

      attributes.each do |key, value|
        after[:latest_version][key] = value
      end
    end

    def apply_tag_preview(after, add_tag_names, remove_tag_names, warnings)
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

    def apply_archive_preview(after, archive, restore, warnings)
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
end
