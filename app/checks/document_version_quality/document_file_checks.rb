module DocumentVersionQuality
  class DocumentFileChecks
    def initialize(document_version:, check_class:)
      @document_version = document_version
      @check_class = check_class
    end

    def call
      document_version.document_files.flat_map do |file|
        [
          document_file_presence_check(file),
          document_file_scan_check(file)
        ].compact
      end
    end

    private

    attr_reader :document_version, :check_class

    def document_file_presence_check(file)
      return info(:document_file_exists, "Document file exists", file.file_name) if file.absolute_path.file?

      error(:document_file_missing, "Document file is missing", file.storage_key)
    rescue ActiveRecord::RecordNotFound => e
      error(:document_file_missing, "Document file storage path is invalid", e.message)
    end

    def document_file_scan_check(file)
      return info(:document_file_scan, "Document file scan is clean", file.file_name) if file.scan_clean?
      return warning(:document_file_scan, "Document file scan is pending", file.file_name) if file.scan_pending?

      error(:document_file_scan, "Document file scan is not clean", "#{file.file_name}: #{file.scan_status}")
    end

    def info(key, message, detail = nil)
      check_class.new(key:, severity: :info, message:, detail:)
    end

    def warning(key, message, detail = nil)
      check_class.new(key:, severity: :warning, message:, detail:)
    end

    def error(key, message, detail = nil)
      check_class.new(key:, severity: :error, message:, detail:)
    end
  end
end
