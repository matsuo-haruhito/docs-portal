class DocumentFile < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "file"

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

  before_validation :normalize_search_text

  def to_param
    public_id
  end

  def absolute_path
    Rails.root.join("storage", "document_files", storage_key)
  end

  def effective_content_type
    type = detected_content_type
    return "#{type}; charset=utf-8" if type.start_with?("text/")

    type
  end

  def inline_disposition?
    INLINE_CONTENT_TYPE_PREFIXES.any? { effective_content_type.start_with?(_1) }
  end

  def downloadable_by?(user)
    return false unless user&.active?
    return true if user.internal?

    document_version.published? && document_version.document.downloadable_by?(user)
  end

  def assign_search_text_from_path!(path)
    self.search_text = DocumentVersion.search_text_for(file_name, storage_key, path)
  end

  private

  def normalize_search_text
    self.search_text = DocumentVersion.search_text_for(search_text)
  end

  def detected_content_type
    EXTENSION_CONTENT_TYPES.fetch(File.extname(file_name).downcase, content_type)
  end
end
