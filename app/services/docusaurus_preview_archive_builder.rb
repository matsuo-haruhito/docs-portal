require "pathname"
require "rubygems/package"
require "tempfile"
require "zlib"

class DocusaurusPreviewArchiveBuilder
  def initialize(version)
    @version = version
  end

  def build
    tempfile = Tempfile.new(["docusaurus-preview-#{version.id}", ".tar.gz"])
    tempfile.binmode

    Zlib::GzipWriter.open(tempfile.path) do |gzip|
      Gem::Package::TarWriter.new(gzip) do |tar|
        version.document_files.order(:sort_order, :id).each do |document_file|
          add_file(tar, document_file)
        end
      end
    end

    tempfile.rewind
    tempfile
  rescue
    tempfile&.close!
    raise
  end

  private

  attr_reader :version

  def add_file(tar, document_file)
    relative_path = safe_relative_path(document_file.file_name)
    absolute_path = document_file.absolute_path
    mode = File.stat(absolute_path).mode

    tar.add_file(relative_path, mode) do |entry|
      File.open(absolute_path, "rb") do |file|
        IO.copy_stream(file, entry)
      end
    end
  end

  def safe_relative_path(value)
    raw_path = value.to_s.tr("\\", "/")
    invalid_absolute = raw_path.start_with?("/") || raw_path.match?(/\A[A-Za-z]:\//)
    path = raw_path.delete_prefix("./")
    normalized = Pathname.new(path).cleanpath.to_s
    invalid = invalid_absolute || normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../") || normalized.include?("\0")
    raise ApplicationError::BadRequest, "Docusaurus preview file path is invalid: #{value}" if invalid

    normalized
  end
end
