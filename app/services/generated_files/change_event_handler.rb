require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "active_support/inflector"
require "pathname"
require "set"

require_relative "file_change_event_registry"

module GeneratedFiles
  class ChangeEventHandler
    DEFAULT_REGISTRY_PATH = FileChangeEventRegistry::DEFAULT_REGISTRY_PATH

    FileEvent = Data.define(:path, :operation)

    def initialize(
      changed_files: nil,
      file_events: nil,
      operation: :update,
      event_source: nil,
      metadata: {},
      registry_path: DEFAULT_REGISTRY_PATH,
      root: nil,
      output: $stdout,
      registry: nil,
      event_buffer_class: EventBuffer
    )
      @root = Pathname(root || default_root).expand_path
      @file_events = normalize_events(file_events, changed_files, operation)
      @event_source = event_source
      @metadata = metadata || {}
      @output = output
      @registry = registry || FileChangeEventRegistry.new(registry_path:, root: @root)
      @event_buffer_class = event_buffer_class
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

    attr_reader :root, :file_events, :event_source, :metadata, :output, :registry, :event_buffer_class

    def default_root
      if defined?(Rails)
        Rails.root
      else
        Pathname(__dir__).join("..", "..", "..").expand_path
      end
    end

    def matching_rules
      registry.rules.reject { generated_event_ignored_by?(_1) }.select { matching_events_for(_1).any? }
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

      params = expand_params(rule.fetch("params", {}), matched_events)
      debounce_seconds = params.delete(:debounce_seconds) || params.delete("debounce_seconds")

      if debounce_seconds.to_i.positive? && !dispatched_buffer_event?
        output.puts "Buffer file change event job: rule=#{rule.fetch('id')} debounce_seconds=#{debounce_seconds}"
        event_buffer_class.new(debounce_seconds: debounce_seconds).add(
          file_events: matched_events.map { { path: _1.path, operation: _1.operation } },
          event_source: event_source,
          metadata: metadata
        )
        return rule.fetch("id")
      end

      job_class_name = rule.fetch("job_class")
      job_class = job_class_name.constantize

      output.puts "Enqueue file change event job: rule=#{rule.fetch('id')} job_class=#{job_class_name}"
      job_class.perform_later(**params)
      rule.fetch("id")
    end

    def dispatched_buffer_event?
      metadata.key?("generated_file_event_public_ids") || metadata.key?(:generated_file_event_public_ids)
    end

    def matching_events_for(rule)
      operations = Array(rule.fetch("operations", ["any"])).map(&:to_s)
      patterns = Array(rule.fetch("path_patterns") { rule.fetch("paths") })

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
        value.each_with_object({}) do |(key, child), hash|
          hash[key.to_sym] = expand_params(child, matched_events)
        end
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

    def changed_files
      file_events.map(&:path).to_set
    end

    def normalize_events(file_events, changed_files, operation)
      if file_events.present?
        return Array(file_events).map do |event|
          if event.respond_to?(:fetch)
            FileEvent.new(
              path: normalize_path(event.fetch("path") { event.fetch(:path) }),
              operation: normalize_operation(event.fetch("operation") { event.fetch(:operation, "update") })
            )
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
  end
end
