require "pathname"
require "tempfile"
require "fileutils"

class DocusaurusPreviewArchiveBuilder
  def initialize(version)
    @version = version
  end

  def build
    tempfile = Tempfile.new(["docusaurus-preview-#{version.id}", ".tar.gz"])
    tempfile.binmode

    Dir.mktmpdir("docusaurus-archive-") do |staging|
      version.document_files.order(:sort_order, :id).each do |document_file|
        stage_file(staging, document_file)
      end

      entries = Dir.children(staging)
      system("tar", "-czf", tempfile.path, "-C", staging, *entries, exception: true)
    end

    tempfile.rewind
    tempfile
  rescue
    tempfile&.close!
    raise
  end

  private

  attr_reader :version

  def stage_file(staging, document_file)
    relative_path = safe_relative_path(document_file.file_name)
    destination = File.join(staging, relative_path)
    FileUtils.mkdir_p(File.dirname(destination))
    FileUtils.cp(document_file.absolute_path, destination)
  end

  def safe_relative_path(value)
    raw_path = value.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "_").tr("\\", "/")
    invalid_absolute = raw_path.start_with?("/") || raw_path.match?(/\A[A-Za-z]:\//)
    path = raw_path.delete_prefix("./")
    normalized = Pathname.new(path).cleanpath.to_s
    invalid = invalid_absolute || normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../") || normalized.include?("\0")
    raise ApplicationError::BadRequest, "Docusaurus preview file path is invalid: #{value}" if invalid

    normalized
  end
end
