require "yaml"

class DocumentPathHistoryMetadata
  METADATA_FILE_NAMES = %w[
    .docs-portal-history.yml
    .docs-portal-history.yaml
    .path-history.yml
    .path-history.yaml
    path-history.yml
    path-history.yaml
  ].freeze
  TOP_LEVEL_KEY = "path_history"
  SUPPORTED_KEYS = %w[slugs site_paths archived deleted].freeze
  STATUS_KEYS = %w[archived deleted].freeze

  Warning = Data.define(:code, :message, :detail)
  StatusEntry = Data.define(:status, :kind, :value, :reason)
  Result = Data.define(:source_file, :metadata, :warnings) do
    def source_file?
      source_file.present?
    end

    def valid?
      warnings.empty?
    end

    def slugs
      Array(metadata["slugs"])
    end

    def site_paths
      Array(metadata["site_paths"])
    end

    def status_entries
      Array(metadata["status_entries"])
    end

    def archived_entries
      status_entries.select { _1.status == "archived" }
    end

    def deleted_entries
      status_entries.select { _1.status == "deleted" }
    end
  end

  def initialize(document_version)
    @document_version = document_version
  end

  def call
    return Result.new(source_file: nil, metadata: {}, warnings: []) unless source_file

    metadata = normalize_metadata(parsed_history)
    Result.new(source_file:, metadata:, warnings: validate_metadata(metadata))
  rescue Psych::Exception => e
    Result.new(source_file:, metadata: {}, warnings: [Warning.new(code: :invalid_yaml, message: "Path history metadata is invalid YAML", detail: e.message)])
  end

  private

  attr_reader :document_version

  def source_file
    @source_file ||= document_version.document_files.order(:sort_order, :id).find do |file|
      METADATA_FILE_NAMES.include?(File.basename(file.file_name.to_s))
    end
  end

  def parsed_history
    data = YAML.safe_load(source_file_content, permitted_classes: [], permitted_symbols: [], aliases: false) || {}
    return {} unless data.is_a?(Hash)

    data.fetch(TOP_LEVEL_KEY, {})
  end

  def source_file_content
    source_file.absolute_path.read
  end

  def normalize_metadata(value)
    return {} unless value.is_a?(Hash)

    value.each_with_object({}) do |(key, raw_value), hash|
      key = key.to_s
      next unless SUPPORTED_KEYS.include?(key)

      if STATUS_KEYS.include?(key)
        entries = normalize_status_entries(key, raw_value)
        hash["status_entries"] = Array(hash["status_entries"]) + entries if entries.any?
      else
        normalized_values = normalize_values(raw_value)
        hash[key] = normalized_values if normalized_values.any?
      end
    end
  end

  def normalize_values(value)
    case value
    when Array
      value.flat_map { normalize_values(_1) }
    when Hash
      value.values.flat_map { normalize_values(_1) }
    else
      [value.to_s.strip].reject(&:blank?)
    end.uniq
  end

  def normalize_status_entries(status, value)
    case value
    when Array
      value.flat_map { normalize_status_entries(status, _1) }
    when Hash
      kind = value["kind"].presence || value[:kind].presence || inferred_status_kind(value)
      raw_value = value["value"].presence || value[:value].presence || value["slug"].presence || value[:slug].presence || value["site_path"].presence || value[:site_path].presence
      reason = value["reason"].presence || value[:reason].presence
      Array(build_status_entry(status:, kind:, value: raw_value, reason:)).compact
    else
      Array(build_status_entry(status:, kind: "site_path", value:, reason: nil)).compact
    end
  end

  def inferred_status_kind(value)
    return "slug" if value.key?("slug") || value.key?(:slug)
    return "site_path" if value.key?("site_path") || value.key?(:site_path)

    "site_path"
  end

  def build_status_entry(status:, kind:, value:, reason:)
    normalized_value = value.to_s.strip
    return if normalized_value.blank?

    StatusEntry.new(status: status.to_s, kind: kind.to_s, value: normalized_value, reason: reason.to_s.presence)
  end

  def validate_metadata(metadata)
    warnings = []
    warnings.concat(unknown_key_warnings)
    warnings.concat(duplicate_value_warnings(metadata))
    warnings.concat(unsupported_status_kind_warnings(metadata))
    warnings
  end

  def unknown_key_warnings
    history = parsed_history
    return [] unless history.is_a?(Hash)

    history.keys.map(&:to_s).reject { SUPPORTED_KEYS.include?(_1) }.map do |key|
      Warning.new(code: :unknown_key, message: "path_history.#{key} is not supported", detail: key)
    end
  end

  def duplicate_value_warnings(metadata)
    metadata.except("status_entries").flat_map do |key, values|
      Array(values).tally.select { |_value, count| count > 1 }.keys.map do |value|
        Warning.new(code: :duplicate_value, message: "path_history.#{key} contains duplicated values", detail: value)
      end
    end
  end

  def unsupported_status_kind_warnings(metadata)
    metadata.fetch("status_entries", []).reject { %w[slug site_path].include?(_1.kind) }.map do |entry|
      Warning.new(code: :unsupported_status_kind, message: "path_history.#{entry.status} kind is not supported", detail: entry.kind)
    end
  end
end
