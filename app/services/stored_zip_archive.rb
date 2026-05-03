class StoredZipArchive
  LocalFileEntry = Data.define(:archive_path, :absolute_path)
  StringEntry = Data.define(:archive_path, :content)

  CENTRAL_DIRECTORY_SIGNATURE = 0x02014b50
  END_OF_CENTRAL_DIRECTORY_SIGNATURE = 0x06054b50
  LOCAL_FILE_HEADER_SIGNATURE = 0x04034b50
  VERSION_NEEDED_TO_EXTRACT = 10
  VERSION_MADE_BY = 20
  GENERAL_PURPOSE_BIT_FLAG = 0
  COMPRESSION_METHOD_STORE = 0
  DEFAULT_FILE_MODE = 0o100644

  def initialize(entries)
    @entries = entries
  end

  def to_binary
    output = String.new.b
    central_directory_entries = []

    entries.each do |entry|
      path = safe_archive_path(entry.archive_path)
      content = entry_content(entry)
      offset = output.bytesize
      crc32 = Zlib.crc32(content)
      size = content.bytesize
      dos_time, dos_date = dos_timestamp

      output << local_file_header(path, crc32, size, dos_time, dos_date)
      output << path.b
      output << content
      central_directory_entries << central_directory_entry(path, crc32, size, offset, dos_time, dos_date)
    end

    central_directory_offset = output.bytesize
    central_directory = central_directory_entries.join.b
    output << central_directory
    output << end_of_central_directory(central_directory_entries.size, central_directory.bytesize, central_directory_offset)
    output
  end

  private

  attr_reader :entries

  def entry_content(entry)
    case entry
    when LocalFileEntry
      File.binread(entry.absolute_path)
    when StringEntry
      entry.content.to_s.b
    else
      raise ArgumentError, "unsupported zip entry: #{entry.class}"
    end
  end

  def safe_archive_path(path)
    value = path.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(value).cleanpath.to_s

    if normalized.blank? || normalized == "." || normalized.start_with?("../") || normalized.include?("/../")
      raise ApplicationError::BadRequest, "zip entry path is invalid: #{path}"
    end

    normalized
  end

  def local_file_header(path, crc32, size, dos_time, dos_date)
    [
      LOCAL_FILE_HEADER_SIGNATURE,
      VERSION_NEEDED_TO_EXTRACT,
      GENERAL_PURPOSE_BIT_FLAG,
      COMPRESSION_METHOD_STORE,
      dos_time,
      dos_date,
      crc32,
      size,
      size,
      path.bytesize,
      0
    ].pack("VvvvvvVVVvv")
  end

  def central_directory_entry(path, crc32, size, offset, dos_time, dos_date)
    [
      CENTRAL_DIRECTORY_SIGNATURE,
      VERSION_MADE_BY,
      VERSION_NEEDED_TO_EXTRACT,
      GENERAL_PURPOSE_BIT_FLAG,
      COMPRESSION_METHOD_STORE,
      dos_time,
      dos_date,
      crc32,
      size,
      size,
      path.bytesize,
      0,
      0,
      0,
      0,
      DEFAULT_FILE_MODE << 16,
      offset
    ].pack("VvvvvvvVVVvvvvvVV") + path.b
  end

  def end_of_central_directory(entry_count, central_directory_size, central_directory_offset)
    [
      END_OF_CENTRAL_DIRECTORY_SIGNATURE,
      0,
      0,
      entry_count,
      entry_count,
      central_directory_size,
      central_directory_offset,
      0
    ].pack("VvvvvVVv")
  end

  def dos_timestamp
    now = Time.current
    dos_time = (now.hour << 11) | (now.min << 5) | (now.sec / 2)
    dos_date = ((now.year - 1980) << 9) | (now.month << 5) | now.day
    [dos_time, dos_date]
  end
end
