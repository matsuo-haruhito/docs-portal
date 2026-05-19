require "pathname"
require "set"
require "yaml"

module GeneratedFiles
  class ChangeEventHandler
    DEFAULT_REGISTRY_PATH = GeneratedFiles::Runner::DEFAULT_REGISTRY_PATH

    def initialize(
      changed_files:,
      event_source: nil,
      metadata: {},
      registry_path: DEFAULT_REGISTRY_PATH,
      root: nil,
      job_class: GeneratedFileJob,
      output: $stdout
    )
      @root = Pathname(root || default_root).expand_path
      @changed_files = normalize_files(changed_files)
      @event_source = event_source
      @metadata = metadata || {}
      @registry_path = absolute_path(registry_path)
      @job_class = job_class
      @output = output
    end

    def call
      job_ids = matching_job_ids
      if job_ids.empty?
        output.puts "No generated-file jobs matched change event."
        output.puts "Event source: #{event_source}" if event_source.present?
        output.puts "Changed files: #{changed_files.to_a.sort.join(', ')}" unless changed_files.empty?
        return []
      end

      job_ids.each do |job_id|
        output.puts "Enqueue generated-file job from change event: #{job_id}"
        job_class.perform_later(
          changed_files: changed_files.to_a.sort,
          job_ids: [job_id],
          event_source:,
          metadata:
        )
      end

      job_ids
    end

    private

    attr_reader :root, :changed_files, :event_source, :metadata, :registry_path, :job_class, :output

    def default_root
      if defined?(Rails)
        Rails.root
      else
        Pathname(__dir__).join("..", "..", "..").expand_path
      end
    end

    def matching_job_ids
      jobs.filter_map do |job|
        watched = normalize_files(Array(job.fetch("source_paths")) + Array(job.fetch("watch_paths", [])))
        job.fetch("id") if watched.any? { changed_files.include?(_1) }
      end
    end

    def jobs
      YAML.safe_load(registry_path.read, permitted_classes: [], aliases: false).fetch("jobs")
    end

    def absolute_path(path)
      path = Pathname(path)
      path.absolute? ? path : root.join(path)
    end

    def normalize_files(files)
      Array(files).each_with_object(Set.new) do |file, result|
        path = file.to_s.strip
        next if path.empty?

        result << Pathname(path).cleanpath.to_s.delete_prefix("./")
      end
    end
  end
end
