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

  enum :scan_status, {
    scan_pending: 0,
    scan_clean: 1,
    scan_infected: 2,
    scan_failed: 3
  }

  validates :file_name, :content_type, :storage_key, presence: true
  validates :file_size, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :sort_order, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  before_validation :normalize_search_text

  def self.storage_root
    Rails.root.join("storage", "document_files")
  end

  def to_param
    public_id
  end

  def absolute_path
    self.class.verified_storage_path(storage_key)
  end

  def self.verified_storage_path(storage_key)
    root = storage_root
    candidate = root.join(storage_key.to_s).cleanpath
    root_path = root.expand_path.to_s
    candidate_path = candidate.expand_path.to_s

    unless candidate_path == root_path || candidate_path.start_with?(root_path + File::SEPARATOR)
      raise ActiveRecord::RecordNotFound, "Document file not found"
    end

    candidate
  end

  def effective_content_type
    type = detected_content_type
    return "#{type}; charset=utf-8" if type.start_with?("text/")

    type
  end

  def inline_disposition?
    INLINE_CONTENT_TYPE_PREFIXES.any? { effective_content_type.start_with?(_1) }
  end

  def deliverable_after_scan?(user)
    return true if user&.internal?

    scan_clean?
  end

  def blocked_by_scan?
    scan_pending? || scan_infected? || scan_failed?
  end

  def downloadable_by?(user)
    return false unless user&.active?
    return true if user.internal?

    scan_clean? && document_version.published? && document_version.document.downloadable_by?(user)
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
