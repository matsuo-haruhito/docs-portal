module DocumentExport
  class PathResolver
    def initialize(user:, zip_path_mode:)
      @user = user
      @zip_path_mode = zip_path_mode.to_sym
    end

    def filename_component(value)
      value.to_s
        .unicode_normalize(:nfkc)
        .gsub(/[\\\/:*?"<>|]/, "-")
        .squish
        .presence || "document"
    end

    def single_version_path(version:, file:)
      return source_path_for(version:, file:) if source_path_mode?

      normalize_relative_file_path(file)
    end

    def multi_version_path(version:, file:, used_paths:)
      candidate =
        if source_path_mode?
          source_path_for(version:, file:)
        else
          File.join(
            filename_component(version.document.slug),
            filename_component(version.version_label),
            normalize_relative_file_path(file)
          )
        end

      unique_path(candidate, used_paths)
    end

    private

    attr_reader :user, :zip_path_mode

    def source_path_mode?
      zip_path_mode == :source_path
    end

    def source_path_for(version:, file:)
      ExportOutputPlan.new(
        project: version.document.project,
        viewer: user,
        files: [file],
        include_source_path: true,
        watermark: false
      ).call.items.first.zip_path
    end

    def normalize_relative_file_path(file)
      path = file.file_name.to_s.tr("\\", "/").delete_prefix("/")
      normalized = Pathname.new(path).cleanpath.to_s
      return File.basename(file.file_name.to_s.presence || file.storage_key) if unsafe_path?(normalized)

      normalized
    end

    def unsafe_path?(path)
      path.blank? || path == "." || path.start_with?("../") || path.include?("/../")
    end

    def unique_path(path, used_paths)
      candidate = path
      basename = File.basename(path, ".*")
      extension = File.extname(path)
      dirname = File.dirname(path)
      index = 2

      while used_paths.include?(candidate)
        candidate = File.join(dirname, "#{basename}-#{index}#{extension}")
        index += 1
      end

      used_paths << candidate
      candidate
    end
  end
end
