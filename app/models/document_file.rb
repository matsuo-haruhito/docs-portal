class DocumentFile < ApplicationRecord
  EXTENSION_CONTENT_TYPES = {
    ".md" => "text/markdown",
    ".markdown" => "text/markdown",
    ".txt" => "text/plain",
    ".csv" => "text/csv",
    ".json" => "application/json",
    ".yml" => "text/yaml",
    ".yaml" => "text/yaml",
    ".html" => "text/html"
  }.freeze

  INLINE_CONTENT_TYPE_PREFIXES = [
    "application/pdf",
    "image/",
    "text/",
    "application/json"
  ].freeze

  belongs_to :document_version

  validates :file_name, :content_type, :storage_key, presence: true

  def absolute_path
    Rails.root.join("storage", "document_files", storage_key)
  end

  def effective_content_type
    return detected_content_type unless content_type == "application/octet-stream"

    detected_content_type
  end

  def inline_disposition?
    INLINE_CONTENT_TYPE_PREFIXES.any? { effective_content_type.start_with?(_1) }
  end

  private

  def detected_content_type
    EXTENSION_CONTENT_TYPES.fetch(File.extname(file_name).downcase, content_type)
  end
end
