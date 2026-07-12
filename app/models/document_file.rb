class DocumentFile < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "file"

  EXTENSION_CONTENT_TYPES = {
    ".md" => "text/markdown",
    ".markdown" => "text/markdown",
    ".mdx" => "text/markdown",
    ".txt" => "text/plain",
    ".csv" => "text/csv",
    ".tsv" => "text/tab-separated-values",
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

  OFFICE_PREVIEW_EXTENSIONS = %w[
    .doc
    .docx
    .xls
    .xlsx
    .ppt
    .pptx
  ].freeze

  belongs_to :document_version

  has_many :external_folder_sync_items, dependent: :nullify

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

  def office_previewable?
    File.extname(file_name.to_s).downcase.in?(OFFICE_PREVIEW_EXTENSIONS)
  end

  def embeddable_viewer_file?
    inline_disposition? || office_previewable?
  end

  def text_previewable?
    preview_content_type = effective_content_type.delete_suffix("; charset=utf-8")

    preview_content_type.start_with?("text/") ||
      preview_content_type.in?(%w[application/json application/x-yaml text/yaml])
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

    scan_clean? &&
      document_version.published? &&
      document_version.within_publication_window? &&
      document_version.document.downloadable_by?(user)
  end

  def assign_search_text_from_path!(path)
    self.search_text = DocumentVersion.search_text_for(file_name, storage_key, path)
  end

  def tree_path
    @tree_path ||= begin
      normalized_name = normalize_relative_path(file_name)
      external_path = external_folder_sync_tree_path
      inferred_path = infer_tree_path_from_storage_key

      if normalized_name.include?("/")
        normalized_name
      else
        external_path.presence || inferred_path.presence || normalized_name
      end
    end
  end

  private

  def normalize_search_text
    self.search_text = DocumentVersion.search_text_for(search_text)
  end

  def detected_content_type
    EXTENSION_CONTENT_TYPES.fetch(File.extname(file_name).downcase, content_type)
  end

  def normalize_relative_path(value)
    path = value.to_s.strip.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(path.presence || "document-file").cleanpath.to_s
    return "document-file" if normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../")

    normalized
  end

  def external_folder_sync_tree_path
    external_folder_sync_items.order(:id).first&.path
  end

  def infer_tree_path_from_storage_key
    segments = storage_key.to_s.tr("\\", "/").split("/")

    case segments.first
    when "zip_uploads"
      segments.drop(4).join("/").presence
    when "git_imports"
      segments.drop(3).join("/").presence
    when "external_folder_syncs"
      segments.drop(3).join("/").presence
    end
  end
end