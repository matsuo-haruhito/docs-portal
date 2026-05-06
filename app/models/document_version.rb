class DocumentVersion < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "ver"

  belongs_to :document
  belongs_to :published_by_user, class_name: "User", optional: true

  has_many :document_files, dependent: :destroy
  has_many :document_review_comments, dependent: :nullify

  enum :status, { draft: 0, published: 1, archived: 2 }

  validates :version_label, :source_commit_hash, presence: true
  validate :published_until_after_published_from

  before_validation :normalize_search_body_text
  after_commit :promote_as_latest_version, on: %i[create update]
  after_commit :broadcast_document_tree_refresh_later

  SOURCE_PATH_FIELDS = %i[
    source_relative_path
    source_directory
    source_file_name
    source_basename
    source_extension
  ].freeze

  SNAPSHOT_KINDS = %w[
    current
    received_markdown
    internal_note
    editable_original
    pdf_generated
    submitted
    attachment
  ].freeze

  def to_param
    public_id
  end

  def site_root_absolute_path
    Rails.root.join("storage", "docs_sites", id.to_s)
  end

  def site_entry_relative_path
    return if site_build_path.blank?

    Pathname.new(site_build_path).join("index.html").to_s
  end

  def site_entry_absolute_path
    return if site_entry_relative_path.blank?

    path = site_root_absolute_path.join(site_entry_relative_path)
    return path if path.exist?

    legacy_html_absolute_path
  end

  def html_absolute_path
    site_entry_absolute_path
  end

  def rendered_site_available?
    site_build_path.present? && site_entry_absolute_path&.exist?
  end

  def html_view_site_path
    markdown_entry_path.presence || site_build_path
  end

  def normalized_html_view_site_path
    self.class.normalize_site_page_path(html_view_site_path)
  end

  def viewable_by?(user)
    return false unless user&.active?
    return true if user.internal?

    published? && within_publication_window? && document.viewable_by?(user)
  end

  def within_publication_window?(at: Time.current)
    return false if published_from.present? && at < published_from
    return false if published_until.present? && at > published_until

    true
  end

  def publication_window_state(at: Time.current)
    return :not_started if published_from.present? && at < published_from
    return :expired if published_until.present? && at > published_until

    :active
  end

  def legacy_html_absolute_path
    Rails.root.join("storage", "docs_sites", site_build_path.to_s, "index.html")
  end

  def assign_source_path_metadata!(source_path:, snapshot_kind: nil)
    metadata = self.class.source_path_metadata_for!(source_path)
    assign_attributes(metadata.merge(snapshot_kind: normalize_snapshot_kind!(snapshot_kind)))
  end

  def assign_search_body_text_from_markdown!(markdown:, source_path: nil)
    self.search_body_text = self.class.search_text_for(markdown, source_path)
  end

  def self.source_path_metadata_for!(source_path)
    normalized = normalize_source_relative_path!(source_path)
    path = Pathname.new(normalized)
    file_name = path.basename.to_s
    extension = File.extname(file_name).delete_prefix(".").presence
    basename = extension ? file_name.delete_suffix(".#{extension}") : file_name

    {
      source_relative_path: normalized,
      source_directory: path.dirname.to_s == "." ? nil : path.dirname.to_s,
      source_file_name: file_name,
      source_basename: basename,
      source_extension: extension
    }
  end

  def self.normalize_source_relative_path!(source_path)
    value = source_path.to_s.strip.tr("\\", "/")
    raise ApplicationError::BadRequest, "source path is required" if value.blank?
    raise ApplicationError::BadRequest, "source path contains invalid characters" if value.include?("\0")
    raise ApplicationError::BadRequest, "source path must be a relative path" if value.start_with?("/")
    raise ApplicationError::BadRequest, "source path must be a relative path" if value.match?(/\A[A-Za-z]:\//)

    normalized = Pathname.new(value).cleanpath.to_s
    invalid_relative_path = normalized.start_with?("../") || normalized == "." || normalized == ".."
    raise ApplicationError::BadRequest, "source path must be a safe relative path" if invalid_relative_path

    normalized
  end

  def self.normalize_site_page_path(path)
    value = path.to_s.delete_prefix("/").sub(%r{\A/+}, "")
    value = value.sub(%r{/(?:index|README)\.(?:md|markdown)\z}i, "")
    value = value.sub(/\.(md|markdown)\z/i, "")
    value = value.delete_suffix("/index.html")
    value = value.delete_suffix(".html")
    value.presence || "index"
  end

  def self.search_text_for(*values)
    values.flatten.compact.join("\n").unicode_normalize(:nfkc).squish.presence
  end

  private

  def normalize_search_body_text
    self.search_body_text = self.class.search_text_for(search_body_text)
  end

  def normalize_snapshot_kind!(value)
    return if value.blank?

    normalized = value.to_s.strip
    unless SNAPSHOT_KINDS.include?(normalized)
      raise ApplicationError::BadRequest, "snapshot kind is invalid: #{value}"
    end

    normalized
  end

  def published_until_after_published_from
    return if published_from.blank? || published_until.blank?
    return if published_until >= published_from

    errors.add(:published_until, "must be after published_from")
  end

  def promote_as_latest_version
    return unless published?
    return if document.blank?

    latest = document.latest_version
    return if latest.present? && latest != self && latest.created_at.to_i > created_at.to_i

    document.update_column(:latest_version_id, id) if document.latest_version_id != id
  end
end
