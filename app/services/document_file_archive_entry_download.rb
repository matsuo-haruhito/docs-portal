class DocumentFileArchiveEntryDownload
  BLOCKED_ARCHIVE_EXTENSIONS = %w[.gz .tar .tgz .zip].freeze

  Result = Data.define(:lookup, :data, :error) do
    include DocumentFilePreviewResultHelpers

    def downloadable?
      lookup.downloadable? && !blocked_archive? && !error?
    end

    def entry_path
      lookup.entry_path
    end

    def filename
      lookup.filename
    end

    def content_type
      lookup.content_type
    end

    def size
      lookup.size
    end

    def reason
      error || lookup.reason
    end

    def blocked_archive?
      File.extname(entry_path.to_s).downcase.in?(BLOCKED_ARCHIVE_EXTENSIONS)
    end
  end

  def initialize(file:, entry_path:, lookup: nil)
    @file = file
    @entry_path = entry_path
    @lookup = lookup
  end

  def call
    current_lookup = lookup || DocumentFileArchiveEntryLookup.new(file:, entry_path:).call
    return unavailable_result(current_lookup) unless current_lookup.downloadable?
    return unavailable_result(current_lookup, error: "nested archive entry はdownload対象外です") if blocked_archive?(current_lookup.entry_path)

    Zip::File.open(file.absolute_path) do |zip_file|
      zip_entry = zip_file.find_entry(current_lookup.entry_path)
      return unavailable_result(current_lookup, error: "entry が見つかりません") unless zip_entry

      Result.new(lookup: current_lookup, data: zip_entry.get_input_stream.read, error: nil)
    end
  rescue Zip::Error, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    unavailable_result(lookup || DocumentFileArchiveEntryLookup.new(file:, entry_path:).call, error: e.message)
  end

  private

  attr_reader :file, :entry_path, :lookup

  def unavailable_result(current_lookup, error: nil)
    Result.new(lookup: current_lookup, data: nil, error: error || current_lookup.reason)
  end

  def blocked_archive?(path)
    File.extname(path.to_s).downcase.in?(BLOCKED_ARCHIVE_EXTENSIONS)
  end
end
