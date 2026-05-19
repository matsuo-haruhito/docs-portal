require "yaml"

module GeneratedFiles
  class ChangeEventHandler
    FileEvent = Data.define(:path, :operation)

    def initialize(registry_path:, file_events: nil, changed_files: nil, event_source: nil, metadata: {}, job_class: GeneratedFileJob)
      @registry_path = Pathname(registry_path)
      @file_events = normalize_file_events(file_events, changed_files)
      @event_source = event_source
      @metadata = metadata
      @job_class = job_class
    end

    def call
      matching_rules.each do |rule, matched_events|
        job_class.perform_later(
          rule.fetch("job_id"),
          params: expand_params(rule.fetch("params", {}), matched_events),
          event_source: event_source,
          metadata: metadata
        )
      end
    end

    private

    attr_reader :registry_path, :file_events, :event_source, :metadata, :job_class

    def normalize_file_events(file_events, changed_files)
      events = Array(file_events).map do |event|
        case event
        when FileEvent
          event
        when Hash
          FileEvent.new(path: event.fetch(:path, event["path"]).to_s, operation: event.fetch(:operation, event["operation"] || "update").to_s)
        else
          FileEvent.new(path: event.to_s, operation: "update")
        end
      end

      events += Array(changed_files).map { |path| FileEvent.new(path: path.to_s, operation: "update") }
      events
    end

    def matching_rules
      rules.filter_map do |rule|
        matched_events = file_events.select { |event| rule_matches_event?(rule, event) }
        [rule, matched_events] if matched_events.any?
      end
    end

    def rule_matches_event?(rule, event)
      operation_matches?(Array(rule.fetch("operations", "any")), event.operation) &&
        Array(rule.fetch("paths")).any? { |pattern| path_matches?(pattern, event.path) }
    end

    def operation_matches?(operations, operation)
      operations = operations.map(&:to_s)
      operations.include?("any") || operations.include?(operation.to_s)
    end

    def path_matches?(pattern, path)
      File.fnmatch?(pattern.to_s, path.to_s, File::FNM_PATHNAME | File::FNM_EXTGLOB) || pattern.to_s == path.to_s
    end

    def expand_params(value, matched_events)
      case value
      when Hash
        value.transform_values { |child| expand_params(child, matched_events) }
      when Array
        value.map { |child| expand_params(child, matched_events) }
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
      YAML.safe_load(registry_path.read, permitted_classes: [Symbol], permitted_symbols: [], aliases: false).fetch("rules")
    end

    def changed_files
      file_events.map(&:path).to_set
    end
  end
end