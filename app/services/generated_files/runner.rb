require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "active_support/inflector"
require "open3"
require "pathname"
require "set"
require "shellwords"
require "yaml"

module GeneratedFiles
  class Runner
    Result = Data.define(:job_id, :command, :generator, :output_writer, :generated_paths, :stdout, :stderr, :status) do
      def success?
        status.respond_to?(:success?) ? status.success? : status == true
      end
    end

    DEFAULT_REGISTRY_PATH = "config/generated_file_jobs.yml"

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
      root: nil,
      output: $stdout,
      error_output: $stderr
    )
      @root = Pathname(root || default_root).expand_path
      @registry_path = absolute_path(registry_path)
      @changed_files = normalize_files(changed_files)
      @job_ids = Array(job_ids).compact.map(&:to_s).to_set
      @output = output
      @error_output = error_output
    end

    def call
      selected_jobs = jobs.select { run_job?(_1) }

      if selected_jobs.empty?
        output.puts "No generated-file jobs matched."
        output.puts "Changed files: #{changed_files.to_a.sort.join(', ')}" unless changed_files.empty?
        return []
      end

      selected_jobs.map { execute_job(_1) }
    end

    private

    attr_reader :root, :registry_path, :changed_files, :job_ids, :output, :error_output

    def default_root
      if defined?(Rails)
        Rails.root
      else
        Pathname(__dir__).join("..", "..", "..").expand_path
      end
    end

    def jobs
      YAML.safe_load(registry_path.read, permitted_classes: [], aliases: false).fetch("jobs")
    end

    def run_job?(job)
      return true if job_ids.include?(job.fetch("id"))
      return false unless job_ids.empty?

      watch_paths = Array(job.fetch("source_paths")) + Array(job.fetch("watch_paths", []))
      normalize_files(watch_paths).any? { changed_files.include?(_1) }
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
        generated_paths:,
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

      result = Result.new(job_id: id, command:, generator: nil, output_writer: nil, generated_paths:, stdout:, stderr:, status:)
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
