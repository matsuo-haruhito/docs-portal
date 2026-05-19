require "yaml"

class DocumentFilePreviewTargetMetadata
  FRONT_MATTER_PATTERN = /\A---\s*\n(?<yaml>.*?)\n---\s*(?:\n|\z)/m
  PREVIEW_TARGET_KEYS = %w[primary attachments hidden debug groups].freeze
  TOP_LEVEL_KEY = "preview_targets"

  Warning = Data.define(:code, :message, :path)
  Result = Data.define(:metadata, :warnings) do
    def valid?
      warnings.empty?
    end

    def paths_for(key)
      Array(metadata[key.to_s])
    end
  end

  def initialize(source:, document_files: [])
    @source = source.to_s
    @document_files = document_files
  end

  def call
    @unsafe_paths = []
    metadata = normalize_metadata(parsed_preview_targets)
    warnings = validate_metadata(metadata)
    Result.new(metadata:, warnings:)
  rescue Psych::Exception => e
    Result.new(metadata: {}, warnings: [Warning.new(code: :invalid_yaml, message: e.message, path: nil)])
  end

  private

  attr_reader :source, :document_files, :unsafe_paths

  def parsed_preview_targets
    data = YAML.safe_load(front_matter_yaml, permitted_classes: [], permitted_symbols: [], aliases: false) || {}
    return data.fetch(TOP_LEVEL_KEY, {}) if data.is_a?(Hash)

    {}
  end

  def front_matter_yaml
    match = source.match(FRONT_MATTER_PATTERN)
    match ? match[:yaml] : source
  end

  def normalize_metadata(value)
    return {} unless value.is_a?(Hash)

    value.each_with_object({}) do |(key, raw_value), hash|
      key = key.to_s
      next unless PREVIEW_TARGET_KEYS.include?(key)

      hash[key] = key == "groups" ? normalize_groups(raw_value) : normalize_paths(raw_value)
    end
  end

  def normalize_groups(value)
    case value
    when Hash
      value.each_with_object({}) do |(group_name, paths), groups|
        normalized_paths = normalize_paths(paths)
        groups[group_name.to_s] = normalized_paths if normalized_paths.any?
      end
    when Array
      value.each_with_index.each_with_object({}) do |(paths, index), groups|
        normalized_paths = normalize_paths(paths)
        groups["group_#{index + 1}"] = normalized_paths if normalized_paths.any?
      end
    else
      normalized_paths = normalize_paths(value)
      normalized_paths.any? ? { "group_1" => normalized_paths } : {}
    end
  end

  def normalize_paths(value)
    normalized_paths =
      case value
      when Array
        value.flat_map { |item| normalize_paths(item) }
      when Hash
        value.values.flat_map { |item| normalize_paths(item) }
      else
        [normalized_path(value)]
      end

    normalized_paths.compact
  end

  def validate_metadata(metadata)
    warnings = []
    warnings.concat(unknown_key_warnings)
    warnings.concat(unsafe_path_warnings)
    warnings.concat(missing_path_warnings(metadata))
    warnings.concat(duplicate_path_warnings(metadata))
    warnings
  end

  def unknown_key_warnings
    targets = parsed_preview_targets
    return [] unless targets.is_a?(Hash)

    targets.keys.map(&:to_s).reject { |key| PREVIEW_TARGET_KEYS.include?(key) }.map do |key|
      Warning.new(code: :unknown_key, message: "preview_targets.#{key} は未対応です", path: nil)
    end
  end

  def unsafe_path_warnings
    unsafe_paths.uniq.map do |path|
      Warning.new(code: :unsafe_relative_path, message: "#{path} は preview target として安全ではない相対パスです", path: path)
    end
  end

  def missing_path_warnings(metadata)
    grouped_paths = Array(metadata["groups"]&.values).flatten
    metadata.except("groups").merge("groups" => grouped_paths).flat_map do |key, paths|
      Array(paths).reject { |path| existing_paths.include?(path) }.map do |path|
        Warning.new(code: :missing_path, message: "#{key} に指定された #{path} が存在しません", path: path)
      end
    end
  end

  def duplicate_path_warnings(metadata)
    grouped_paths = Array(metadata["groups"]&.values).flatten
    all_paths = metadata.except("groups").flat_map { |_key, paths| Array(paths) } + grouped_paths
    all_paths.tally.select { |_path, count| count > 1 }.keys.map do |path|
      Warning.new(code: :duplicate_path, message: "#{path} が複数の preview target に指定されています", path: path)
    end
  end

  def existing_paths
    @existing_paths ||= document_files.map(&:tree_path).to_set
  end

  def normalized_path(value)
    raw_path = value.to_s.strip.tr("\\", "/")
    path = raw_path.delete_prefix("/")
    normalized = Pathname.new(path.presence || ".").cleanpath.to_s
    if normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../")
      unsafe_paths << raw_path.presence || value.inspect
      return nil
    end

    normalized
  end
end
