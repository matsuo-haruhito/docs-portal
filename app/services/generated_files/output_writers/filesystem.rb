require "fileutils"
require "pathname"

module GeneratedFiles
  module OutputWriters
    class Filesystem
      def initialize(root: nil)
        @root = Pathname(root || default_root).expand_path
      end

      def write(artifacts)
        Array(artifacts).map do |artifact|
          path = absolute_path(artifact.path)
          FileUtils.mkdir_p(path.dirname)
          path.write(artifact.content, mode: "w", encoding: "UTF-8")
          relative(path)
        end
      end

      private

      attr_reader :root

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
