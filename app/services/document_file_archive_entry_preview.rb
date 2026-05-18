class DocumentFileArchiveEntryPreview
  DEFAULT_LINE_LIMIT = 2_000

  Result = Data.define(:lookup, :text, :lines, :truncated, :line_limit, :error) do
    include DocumentFilePreviewResultHelpers

    def previewable?
      lookup.previewable? && !error?
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

    def line_count
      lines.count
    end
  end

  def initialize(file:, entry_path:, line_limit: DEFAULT_LINE_LIMIT, lookup: nil)
    @file = file
    @entry_path = entry_path
    @line_limit = line_limit
    @lookup = lookup
  end

  def call
    current_lookup = lookup || DocumentFileArchiveEntryLookup.new(file:, entry_path:).call
    return unavailable_result(current_lookup) unless current_lookup.previewable?

    Zip::File.open(file.absolute_path) do |zip_file|
      zip_entry = zip_file.find_entry(current_lookup.entry_path)
      return unavailable_result(current_lookup, error: "entry が見つかりません") unless zip_entry

      text = zip_entry.get_input_stream.read
      text.force_encoding("UTF-8")
      raise Encoding::InvalidByteSequenceError, "invalid byte sequence in UTF-8" unless text.valid_encoding?

      lines = []
      text.each_line.with_index do |line, index|
        return Result.new(lookup: current_lookup, text:, lines:, truncated: true, line_limit:, error: nil) if index >= line_limit

        lines << line.chomp
      end

      Result.new(lookup: current_lookup, text:, lines:, truncated: false, line_limit:, error: nil)
    end
  rescue Zip::Error, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError => e
    unavailable_result(lookup || DocumentFileArchiveEntryLookup.new(file:, entry_path:).call, error: e.message)
  end

  private

  attr_reader :file, :entry_path, :line_limit, :lookup

  def unavailable_result(current_lookup, error: nil)
    Result.new(lookup: current_lookup, text: nil, lines: [], truncated: false, line_limit:, error: error || current_lookup.reason)
  end
end
