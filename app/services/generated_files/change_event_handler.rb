require "fileutils"
require "pathname"
require "set"
require "yaml"

module GeneratedFiles
  class ChangeEventHandler
    DEFAULT_REGISTRY_PATH = "config/file_change_event_jobs.yml"

    FileEvent = Data.define(:path, :operation)

    def initialize(
      changed_files: nil,
      file_events: nil,
      operation: :update,
      event_source: nil,
      metadata: {},
      registry_path: DEFAULT_REGISTRY_PATH,
      root: nil,
      output: $stdout
    )
      @root = Pathname(root || default_root).expand_path
      @file_events = normalize_events(file_events, changed_files, operation)
      @event_source = event_source
      @metadata = metadata || {}
      @registry_path = absolute_path(registry_path)
      @output = output
    end

    def call
      enqueued_rules = matching_rules.filter_map { enqueue_rule(_1) }
      if enqueued_rules.empty?
        output.puts "No file change event jobs matched."
        output.puts "Event source: #{event_source}" if event_source.present?
        output.puts "Changed files: #{changed_files.to_a.sort.join(', ')}" unless changed_files.empty?
      end

      enqueued_rules
    end

    private

    attr_reader :root, :file_events, :event_source, :metadata, :registry_path, :output

    def default_root
      if defined?(Rails)
        Rails.root
      else
        Pathname(__dir__).join("..", "..", "..").expand_path
      end
    end

    def matching_rules
      rules.reject { generated_event_ignored_by?(_1) }.select { matching_events_for(_1).any? }
    end

    def generated_event_ignored_by?(rule)
      return false unless generated_event?

      rule.fetch("ignore_generated_events", true) != false
    end

    def generated_event?
      metadata.fetch("generated_by_job") { metadata.fetch(:generated_by_job, false) } == true
    end

    def enqueue_rule(rule)
      matched_events = matching_events_for(rule)
      return if matched_events.empty?

      job_class_name = rule.fetch("job_class")
      job_class = job_class_name.constantize
      params = expand_params(rule.fetch("params", {}), matched_events)

      output.puts "Enqueue file change event job: rule=#{rule.fetch('id')} job_class=#{job_class_name}"
      job_class.perform_later(**params.deep_symbolize_keys)
      rule.fetch("id")
    end

    def matching_events_for(rule)
      operations = Array(rule.fetch("operations", ["any"])).map { _1.to_s }
      patterns = Array(rule.fetch("path_patterns"))

      file_events.select do |event|
        operation_matches?(operations, event.operation) && patterns.any? { path_matches?(_1, event.path) }
      end
    end

    def operation_matches?(operations, operation)
      operations.include?("any") || operations.include?(operation.to_s)
    end

    def path_matches?(pattern, path)
      File.fnmatch?(pattern.to_s, path.to_s, File::FNM_PATHNAME | File::FNM_EXTGLOB) || pattern.to_s == path.to_s
    end

    def expand_params(value, matched_events)
      case value
      when Hash
        value.transform_values { expand_params(_1, matched_events) }
      when Array
        value.map { expand_params(_1, matched_events) }
      when "$changed_files"
        changed_files.to_a.sort
      when "$matched_files"
        matched_events.map(&:path).uniq.sort
      when "$event_source"
        event_source
      when "$metadata"
        metadata
      when "$operations"
        matched_events.map(&:operation).uniq.sort
      else
        value
      end
    end

    def rules
      YAML.safe_load(registry_path.read, permitted_classes: [], aliases: false).fetch("rules")
    end

    def changed_files
      file_events.map(&:path).to_set
    end

    def normalize_events(file_events, changed_files, operation)
      if file_events.present?
        return Array(file_events).map do |event|
          if event.respond_to?(:fetch)
            FileEvent.new(path: normalize_path(event.fetch("path") { event.fetch(:path) }), operation: normalize_operation(event.fetch("operation") { event.fetch(:operation) }))
          else
            FileEvent.new(path: normalize_path(event), operation: normalize_operation(operation))
          end
        end
      end

      Array(changed_files).map do |path|
        FileEvent.new(path: normalize_path(path), operation: normalize_operation(operation))
      end
    end

    def normalize_path(path)
      Pathname(path.to_s.strip).cleanpath.to_s.delete_prefix("./")
    end

    def normalize_operation(operation)
      operation.to_s.presence || "update"
    end

    def absolute_path(path)
      path = Pathname(path)
      path.absolute? ? path : root.join(path)
    end
  end
end
