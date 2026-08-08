require "fileutils"
require "pathname"
require "tmpdir"

module GeneratedFiles
  module OutputWriters
    class Filesystem
      def initialize(root: nil, dispatch_claim: nil)
        @root = Pathname(root || default_root).expand_path
        @dispatch_claim = dispatch_claim
      end

      def write(artifacts)
        return write_directly(artifacts) unless dispatch_claim

        write_with_claim(artifacts)
      end

      private

      attr_reader :root, :dispatch_claim

      def write_directly(artifacts)
        Array(artifacts).map do |artifact|
          path = absolute_path(artifact.path)
          FileUtils.mkdir_p(path.dirname)
          path.write(artifact.content, mode: "w", encoding: "UTF-8")
          relative(path)
        end
      end

      def write_with_claim(artifacts)
        staging_directory = Pathname(Dir.mktmpdir("generated-files-", staging_root.to_s))
        staged_outputs = Array(artifacts).each_with_index.map do |artifact, index|
          staged_path = staging_directory.join(index.to_s)
          staged_path.write(artifact.content, mode: "w", encoding: "UTF-8")
          [staged_path, absolute_path(artifact.path)]
        end

        GeneratedFiles::EventDispatchLease.with_ownership!(dispatch_claim) do
          staged_outputs.each do |staged_path, final_path|
            FileUtils.mkdir_p(final_path.dirname)
            File.rename(staged_path, final_path)
          end
        end

        staged_outputs.map { |_staged_path, final_path| relative(final_path) }
      ensure
        FileUtils.rm_rf(staging_directory) if defined?(staging_directory) && staging_directory
      end

      def staging_root
        root.join("tmp", "generated_file_staging").tap { FileUtils.mkdir_p(_1) }
      end

      def default_root
        if defined?(Rails)
          Rails.root
        else
          Pathname(__dir__).join("..", "..", "..", "..").expand_path
        end
      end

      def absolute_path(path)
        path = Pathname(path)
        path.absolute? ? path : root.join(path)
      end

      def relative(path)
        Pathname(path).relative_path_from(root).to_s
      end
    end
  end
end
