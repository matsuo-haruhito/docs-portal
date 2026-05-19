require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "active_support/inflector"
require "open3"
require "pathname"
require "set"
require "shellwords"

require_relative "generated_job_registry"
require_relative "run_recorder"

module GeneratedFiles
  class Runner
    Result = Data.define(:job_id, :command, :generator, :output_writer, :generated_paths, :stdout, :stderr, :status) do
      def success?
        status.respond_to?(:success?) ? status.success? : status == true
      end
    end

    DEFAULT_REGISTRY_PATH = GeneratedJobRegistry::DEFAULT_REGISTRY_PATH

    GENERATORS = {
      "ai_usecase_decision_flow" => {
        class_name: "GeneratedFiles::Generators::AiUsecaseDecisionFlow",
        require_path: "generators/ai_usecase_decision_flow"
      }
    }.freeze

    OUTPUT_WRITERS = {
      "filesystem" => {
        class_name: "GeneratedFiles::OutputWriters::Filesystem",
        require_path: "output_writers/filesystem"
      },
      "document_version" => {
        class_name: "GeneratedFiles::OutputWriters::DocumentVersion",
        require_path: "output_writers/document_version"
      }
    }.freeze

    def initialize(
      registry_path: DEFAULT_REGISTRY_PATH,
      changed_files: nil,
      job_ids: nil,
      event_source: nil,
      metadata: {},
      root: nil,
      output: $stdout,
      error_output: $stderr,
      run_recorder: RunRecorder.new,
      registry: nil
    )
      @root = Pathname(root || default_root).expand_path
      @changed_files = normalize_files(changed_files)
      @job_ids = Array(job_ids).compact.map(&:to_s).to_set
      @event_source = event_source
      @metadata = metadata || {}
      @output = output
      @error_output = error_output
      @run_recorder = run_recorder
      @registry = registry || GeneratedJobRegistry.new(registry_path:, root: @root)
    end

    def call
      selected_jobs = registry.select(changed_files: changed_files.to_a, job_ids: job_ids.to_a)

      if selected_jobs.empty?
        output.puts "No generated-file jobs matched."
        output.puts "Changed files: #{changed_files.to_a.sort.join(', ')}" unless changed_files.empty?
        return []
      end

      selected_jobs.map { execute_job_with_recording(_1) }
    end

    private

    attr_reader :root, :changed_files, :job_ids, :event_source, :metadata,
      :output, :error_output, :run_recorder, :registry

    def default_root
      if defined?(Rails)
        Rails.root
      else
        Pathname(__dir__).join("..", "..", "..").expand_path
      end
    end

    def execute_job_with_recording(job)
      run = run_recorder.start(job: job, changed_files: changed_files.to_a.sort, event_source: event_source, metadata: metadata)
      result = execute_job(job)
      run.finish!(status: :completed, generated_paths: result.generated_paths)
      result
    rescue StandardError => error
      run.finish!(status: :failed, error_message: error.message) if defined?(run) && run
      raise
    end

    def execute_job(job)
      if job.key?("generator")
        execute_generator_job(job)
      else
        execute_command_job(job)
      end
    end

    def execute_generator_job(job)
      id = job.fetch("id")
      generator_key = job.fetch("generator")
      output_writer_key = job.fetch("output_writer", "filesystem")
      options = job.fetch("options", {})
      output_options = job.fetch("output_options", {})

      output.puts "Running generated-file job: #{id}"
      output.puts "Generator: #{generator_key}"
      output.puts "Output writer: #{output_writer_key}"

      artifacts = generator_class_for(generator_key).new(**options.deep_symbolize_keys.merge(root: root)).call
      generated_paths = output_writer_class_for(output_writer_key)
        .new(**output_options.deep_symbolize_keys.merge(root: root))
        .write(artifacts)

      result = Result.new(
        job_id: id,
        command: nil,
        generator: generator_key,
        output_writer: output_writer_key,
        generated_paths: generated_paths,
        stdout: "",
        stderr: "",
        status: true
      )
      output_generated_paths(id, generated_paths)
      result
    end

    def execute_command_job(job)
      id = job.fetch("id")
      command = job.fetch("command")
      generated_paths = Array(job.fetch("generated_paths", []))

      output.puts "Running generated-file job: #{id}"
      output.puts "Command: #{command}"

      stdout, stderr, status = Open3.capture3(command, chdir: root.to_s)
      output.puts stdout unless stdout.empty?
      error_output.puts stderr unless stderr.empty?

      result = Result.new(job_id: id, command: command, generator: nil, output_writer: nil, generated_paths: generated_paths, stdout: stdout, stderr: stderr, status: status)
      raise "generated-file job failed: #{id}" unless result.success?

      output_generated_paths(id, generated_paths)
      result
    end

    def generator_class_for(generator_key)
      generator = GENERATORS.fetch(generator_key) do
        raise KeyError, "Unknown generated-file generator: #{generator_key}"
      end
      require_relative generator.fetch(:require_path)
      generator.fetch(:class_name).constantize
    end

    def output_writer_class_for(output_writer_key)
      writer = OUTPUT_WRITERS.fetch(output_writer_key) do
        raise KeyError, "Unknown generated-file output writer: #{output_writer_key}"
      end
      require_relative writer.fetch(:require_path)
      writer.fetch(:class_name).constantize
    end

    def output_generated_paths(id, generated_paths)
      if generated_paths.empty?
        output.puts "No generated paths produced for #{id}."
      else
        output.puts "Generated paths:"
        generated_paths.each { output.puts "- #{_1}" }
      end
    end

    def normalize_files(files)
      Array(files).each_with_object(Set.new) do |file, result|
        path = file.to_s.strip
        next if path.empty?

        normalized_path = Pathname(path).cleanpath.to_s.delete_prefix("./")
        next if normalized_path.blank? || normalized_path == "."

        result << normalized_path
      end
    end
  end
end
