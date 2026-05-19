require "pathname"
require "yaml"

module GeneratedFiles
  class FileChangeEventRegistry
    DEFAULT_REGISTRY_PATH = "config/file_change_event_jobs.yml"

    def initialize(registry_path: DEFAULT_REGISTRY_PATH, root: nil)
      @root = Pathname(root || default_root).expand_path
      @registry_path = absolute_path(registry_path)
    end

    def rules
      @rules ||= YAML.safe_load(registry_path.read, permitted_classes: [Symbol], permitted_symbols: [], aliases: false).fetch("rules")
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
  end
end