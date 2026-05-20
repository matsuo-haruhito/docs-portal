require "pathname"
require "set"
require "yaml"

module GeneratedFiles
  class GeneratedJobRegistry
    DEFAULT_REGISTRY_PATH = "config/generated_file_jobs.yml"
    KNOWN_GENERATORS = %w[ai_usecase_decision_flow].freeze
    KNOWN_OUTPUT_WRITERS = %w[filesystem document_version].freeze

    def initialize(registry_path: DEFAULT_REGISTRY_PATH, root: nil)
      @root = Pathname(root || default_root).expand_path
      @registry_path = absolute_path(registry_path)
    end

    def jobs
      @jobs ||= normalized_config.fetch("jobs")
    end

    def validate!
      errors = []
      config = normalized_config
      unless config["jobs"].is_a?(Array)
        raise_validation_error(["jobs must be an array"])
      end

      ids = Hash.new(0)
      config.fetch("jobs").each_with_index do |job, index|
        label = "jobs[#{index}]"
        unless job.is_a?(Hash)
          errors << "#{label} must be a hash"
          next
        end

        id = job["id"].to_s.strip
        errors << "#{label}.id is required" if id.blank?
        ids[id] += 1 if id.present?

        watched_paths = normalize_files(Array(job["source_paths"]) + Array(job["watch_paths"]))
        errors << "#{label} must include at least one source_paths/watch_paths entry" if watched_paths.empty?

        unless job["command"].present? || job["generator"].present?
          errors << "#{label} must include command or generator"
        end

        generator = job["generator"].to_s.strip
        if generator.present? && !KNOWN_GENERATORS.include?(generator)
          errors << "#{label}.generator is unknown: #{generator}"
        end

        output_writer = job["output_writer"].to_s.strip
        if output_writer.present? && !KNOWN_OUTPUT_WRITERS.include?(output_writer)
          errors << "#{label}.output_writer is unknown: #{output_writer}"
        end

        generated_paths = job.key?("generated_paths") ? job["generated_paths"] : []
        errors << "#{label}.generated_paths must be an array" unless generated_paths.is_a?(Array)
      end

      ids.select { |_id, count| count > 1 }.each_key do |id|
        errors << "duplicate generated file job id: #{id}"
      end

      raise_validation_error(errors) if errors.any?
      true
    end

    def select(changed_files:, job_ids: [])
      normalized_changed_files = normalize_files(changed_files)
      normalized_job_ids = Array(job_ids).compact.map(&:to_s).to_set

      jobs.select do |job|
        next true if normalized_job_ids.include?(job.fetch("id"))
        next false unless normalized_job_ids.empty?

        watched_paths = normalize_files(Array(job.fetch("source_paths", [])) + Array(job.fetch("watch_paths", [])))
        watched_paths.any? { |path| normalized_changed_files.include?(path) }
      end
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

    def normalize_files(files)
      Array(files).each_with_object(Set.new) do |file, result|
        path = file.to_s.strip
        next if path.empty?

        normalized_path = Pathname(path).cleanpath.to_s.delete_prefix("./")
        next if normalized_path.empty? || normalized_path == "."

        result << normalized_path
      end
    end

    def raise_validation_error(errors)
      raise ArgumentError, "generated_file_jobs.yml is invalid:\n- #{errors.join("\n- ")}"
    end
  end
end