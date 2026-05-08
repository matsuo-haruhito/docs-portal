module ZipImport
  class ArchiveExtractor
    def initialize(uploaded_file:, zip_path:, extracted_root:, max_entry_count:, max_total_uncompressed_bytes:)
      @uploaded_file = uploaded_file
      @zip_path = Pathname(zip_path)
      @extracted_root = Pathname(extracted_root)
      @max_entry_count = max_entry_count
      @max_total_uncompressed_bytes = max_total_uncompressed_bytes
    end

    def call
      copy_uploaded_zip!
      extract_zip!
    end

    private

    attr_reader :uploaded_file, :zip_path, :extracted_root, :max_entry_count, :max_total_uncompressed_bytes

    def copy_uploaded_zip!
      io = uploaded_io
      io.rewind if io.respond_to?(:rewind)
      File.open(zip_path, "wb") do |file|
        IO.copy_stream(io, file)
      end
    end

    def extract_zip!
      entry_count = 0
      total_bytes = 0
      extracted_paths = []

      Zip::File.open(zip_path) do |zip_file|
        zip_file.each do |entry|
          next if entry.directory?

          entry_count += 1
          raise ApplicationError::BadRequest, "ZIP contains too many files" if entry_count > max_entry_count

          safe_path = safe_relative_path(entry.name)
          total_bytes += entry.size
          raise ApplicationError::BadRequest, "ZIP is too large after extraction" if total_bytes > max_total_uncompressed_bytes

          destination = extracted_root.join(safe_path)
          FileUtils.mkdir_p(destination.dirname)
          File.open(destination, "wb") do |file|
            IO.copy_stream(entry.get_input_stream, file)
          end
          extracted_paths << destination
        end
      end

      extracted_paths
    rescue Zip::Error => e
      raise ApplicationError::BadRequest, "ZIP extraction failed: #{e.message}"
    end

    def safe_relative_path(raw_path)
      normalized = raw_path.to_s.tr("\\", "/").delete_prefix("/")
      path = Pathname.new(normalized).cleanpath.to_s
      invalid = path.blank? || path == "." || path == ".." || path.start_with?("../") || path.include?("/../")
      raise ApplicationError::BadRequest, "ZIP entry path is invalid: #{raw_path}" if invalid

      path.split("/").map { FileNameNormalizer.new(_1, fallback: "file").call }.join("/")
    end

    def uploaded_io
      if uploaded_file.respond_to?(:tempfile)
        uploaded_file.tempfile
      elsif uploaded_file.respond_to?(:read)
        uploaded_file
      else
        raise ApplicationError::BadRequest, "zip_file is invalid"
      end
    end
  end
end
