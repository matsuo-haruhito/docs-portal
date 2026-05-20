require "pathname"
require "yaml"

module GeneratedFiles
  class FileChangeEventRegistry
    DEFAULT_REGISTRY_PATH = "config/file_change_event_jobs.yml"
    KNOWN_OPERATIONS = %w[create update delete any].freeze
    RESERVED_PARAM_TOKENS = %w[$changed_files $matched_files $event_source $metadata $operations].freeze

    def initialize(registry_path: DEFAULT_REGISTRY_PATH, root: nil)
      @root = Pathname(root || default_root).expand_path
      @registry_path = absolute_path(registry_path)
    end

    def rules
      @rules ||= normalized_config.fetch("rules")
    end

    def validate!
      errors = []
      config = normalized_config

      unless config["rules"].is_a?(Array)
        raise_validation_error(["rules must be an array"])
      end

      ids = Hash.new(0)

      config.fetch("rules").each_with_index do |rule, index|
        label = "rules[#{index}]"

        unless rule.is_a?(Hash)
          errors << "#{label} must be a hash"
          next
        end

        id = rule["id"].to_s.strip
        errors << "#{label}.id is required" if id.blank?
        ids[id] += 1 if id.present?

        operations = Array(rule["operations"]).map(&:to_s)
        errors << "#{label}.operations is required" if operations.empty?
        operations.each do |operation|
          errors << "#{label}.operations includes unknown value: #{operation}" unless KNOWN_OPERATIONS.include?(operation)
        end

        paths_present = Array(rule["path_patterns"]).any?(&:present?) || Array(rule["paths"]).any?(&:present?)
        errors << "#{label} must include path_patterns or paths" unless paths_present

        job_class_name = rule["job_class"].to_s.strip
        if job_class_name.blank?
          errors << "#{label}.job_class is required"
        else
          begin
            job_class_name.constantize
          rescue NameError
            errors << "#{label}.job_class could not be constantized: #{job_class_name}"
          end
        end

        validate_param_tokens!(errors, label, rule["params"])

        debounce_seconds = rule.dig("params", "debounce_seconds")
        if debounce_seconds.present? && debounce_seconds.to_i <= 0
          errors << "#{label}.params.debounce_seconds must be positive"
        end
      end

      ids.select { |_id, count| count > 1 }.each_key do |id|
        errors << "duplicate file change event rule id: #{id}"
      end

      raise_validation_error(errors) if errors.any?
      true
    end

    private

    attr_reader :root, :registry_path

    def normalized_config
      @normalized_config ||= normalize_registry(YAML.safe_load(registry_path.read, permitted_classes: [Symbol], permitted_symbols: [], aliases: false))
    end

    def default_root
      if defined?(Rails)
        Rails.root
      else
        Pathname(__dir__).join("..", "..", "..").expand_path
      end
    end

    def absolute_path(path)
      path = Pathname(path)
      path.absolute? ? path : root.join(path)
    end

    def normalize_registry(value)
      case value
      when Hash
        value.each_with_object({}) { |(key, child), hash| hash[key.to_s] = normalize_registry(child) }
      when Array
        value.map { |child| normalize_registry(child) }
      else
        value
      end
    end

    def validate_param_tokens!(errors, label, value)
      case value
      when Hash
        value.each_value { |child| validate_param_tokens!(errors, label, child) }
      when Array
        value.each { |child| validate_param_tokens!(errors, label, child) }
      when String
        return unless value.start_with?("$")
        return if RESERVED_PARAM_TOKENS.include?(value)

        errors << "#{label}.params includes unknown reserved token: #{value}"
      end
    end

    def raise_validation_error(errors)
      raise ArgumentError, "file_change_event_jobs.yml is invalid:\n- #{errors.join("\n- ")}"
    end
  end
end