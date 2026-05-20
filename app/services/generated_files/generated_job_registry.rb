require "pathname"
require "set"
require "yaml"

module GeneratedFiles
  class GeneratedJobRegistry
    DEFAULT_REGISTRY_PATH = "config/generated_file_jobs.yml"

    def initialize(registry_path: DEFAULT_REGISTRY_PATH, root: nil)
      @root = Pathname(root || default_root).expand_path
      @registry_path = absolute_path(registry_path)
    end

    def jobs
      @jobs ||= normalize_registry(YAML.safe_load(registry_path.read, permitted_classes: [Symbol], permitted_symbols: [], aliases: false)).fetch("jobs")
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
  end
end
