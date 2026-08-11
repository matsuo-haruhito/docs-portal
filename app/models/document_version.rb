class DocumentVersion < ApplicationRecord
  include PublicIdentifiable

  public_id_prefix "ver"

  belongs_to :document
  belongs_to :published_by_user, class_name: "User", optional: true

  has_many :document_files, dependent: :destroy
  has_many :document_review_comments, dependent: :nullify
  has_many :external_folder_sync_items, dependent: :nullify

  enum :status, { draft: 0, published: 1, archived: 2 }
  MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze
  PREVIEW_BUILD_MAX_ATTEMPTS = 5
  PREVIEW_BUILD_QUEUE_STALE_AFTER = 10.minutes
  PREVIEW_BUILD_RUNNING_STALE_AFTER = 20.minutes
  PREVIEW_BUILD_RETRY_DELAYS = [1.minute, 5.minutes, 15.minutes, 1.hour].freeze

  enum :preview_build_status, {
    preview_not_requested: 0,
    preview_queued: 1,
    preview_running: 2,
    preview_succeeded: 3,
    preview_failed: 4,
    preview_abandoned: 5
  }

  validates :version_label, :source_commit_hash, presence: true
  validates :preview_build_attempt_count, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :published_until_after_published_from

  before_validation :normalize_search_body_text
  after_create_commit -> { promote_as_latest_version }, if: :published?
  after_update_commit -> { promote_as_latest_version }, if: :published_status_transition?
  after_commit :broadcast_document_tree_refresh_later, unless: :preview_build_only_change?

  scope :markdown_preview_builds, -> {
    where(
      "LOWER(COALESCE(source_relative_path, '')) LIKE :md OR " \
        "LOWER(COALESCE(source_relative_path, '')) LIKE :markdown OR " \
        "LOWER(COALESCE(source_relative_path, '')) LIKE :mdx",
      md: "%.md",
      markdown: "%.markdown",
      mdx: "%.mdx"
    )
  }

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
    git_import
  ].freeze

  def to_param
    public_id
  end

  def site_root_absolute_path
    Rails.root.join("storage", "docs_sites", id.to_s)
  end

  def site_entry_relative_path
    return if site_build_path.blank?
    return "index.html" if site_build_path == "index"

    nested_path = Pathname.new(site_build_path).join("index.html").to_s
    return nested_path if site_root_absolute_path.join(nested_path).file?

    flat_path = "#{site_build_path}.html"
    return flat_path if site_root_absolute_path.join(flat_path).file?

    nested_path
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

  def embedded_view_available?
    rendered_site_available? || embedded_view_file.present?
  end

  def embedded_view_file
    @embedded_view_file ||= document_files.order(:sort_order, :id).detect(&:embeddable_viewer_file?)
  end

  def html_view_site_path
    markdown_entry_path.presence || site_build_path
  end

  def normalized_html_view_site_path
    self.class.normalize_site_page_path(html_view_site_path)
  end

  def markdown_preview_buildable?
    File.extname(source_relative_path.to_s).downcase.in?(MARKDOWN_EXTENSIONS)
  end

  enum :preview_build_reason, {
    source_build: 0,
    artifact_recovery: 1
  }, prefix: true

  def mark_preview_build_queued!(at: Time.current, recover_active: false, consume_stale_attempt: false, build_reason: nil)
    with_lock do
      reload
      if build_reason.present?
        requested_reason = build_reason.to_sym
        starting_artifact_recovery =
          requested_reason == :artifact_recovery &&
          (preview_succeeded? || (preview_abandoned? && preview_build_reason_source_build? && site_build_path.present?))
        return false unless starting_artifact_recovery

        if preview_build_reason_source_build?
          self.preview_build_reason = :artifact_recovery
          self.preview_build_attempt_count = 0
        end
      end

      stale_queue_recovery = consume_stale_attempt && preview_build_queue_stale?(at:)
      return false if consume_stale_attempt && !stale_queue_recovery
      return false if preview_abandoned? && build_reason.blank?
      return false if preview_queued? && !recover_active
      return false if preview_running? && !recover_active

      if preview_build_attempts_exhausted?
        transition_preview_build_to_abandoned!(at:, error: "Docusaurus preview build reached the maximum attempt count")
        return false
      end

      next_attempt_count = preview_build_attempt_count + (stale_queue_recovery ? 1 : 0)
      if next_attempt_count >= PREVIEW_BUILD_MAX_ATTEMPTS
        self.preview_build_attempt_count = next_attempt_count
        transition_preview_build_to_abandoned!(at:, error: "Docusaurus preview build queue did not start before the maximum recovery count")
        return false
      end

      update!(
        preview_build_status: :preview_queued,
        preview_build_attempt_count: next_attempt_count,
        preview_build_error_message: nil,
        preview_build_enqueued_at: at,
        preview_build_started_at: nil,
        preview_build_retry_at: nil,
        preview_build_claim_token: nil,
        preview_build_completed_at: nil,
        preview_build_reconciled_at: nil
      )
    end

    true
  end

  def claim_preview_build!(claim_token: SecureRandom.uuid, at: Time.current)
    with_lock do
      reload
      return unless preview_queued?

      if preview_build_attempts_exhausted?
        transition_preview_build_to_abandoned!(at:, error: "Docusaurus preview build reached the maximum attempt count")
        return
      end

      update!(
        preview_build_status: :preview_running,
        preview_build_attempt_count: preview_build_attempt_count + 1,
        preview_build_error_message: nil,
        preview_build_attempted_at: at,
        preview_build_started_at: at,
        preview_build_retry_at: nil,
        preview_build_claim_token: claim_token,
        preview_build_completed_at: nil,
        preview_build_reconciled_at: nil
      )
    end

    claim_token
  end

  def mark_preview_build_running!
    mark_preview_build_queued!(recover_active: true) unless preview_queued?
    claim_preview_build!
  end

  def mark_preview_build_succeeded!(claim_token: nil, at: Time.current, reconciled: false)
    changed = false

    with_lock do
      reload
      if claim_token.present?
        return false unless preview_running? && preview_build_claim_token == claim_token
      elsif preview_running?
        return false
      end

      update!(
        preview_build_status: :preview_succeeded,
        preview_build_error_message: nil,
        preview_build_retry_at: nil,
        preview_build_claim_token: nil,
        preview_build_completed_at: at,
        preview_build_reconciled_at: (reconciled ? at : preview_build_reconciled_at)
      )
      changed = true
    end

    broadcast_preview_ready if changed
    changed
  end

  def mark_preview_build_failed!(error, claim_token: nil, at: Time.current)
    with_lock do
      reload
      if claim_token.present?
        return false unless preview_running? && preview_build_claim_token == claim_token
      elsif preview_running?
        return false
      end

      if preview_build_attempts_exhausted?
        transition_preview_build_to_abandoned!(at:, error:)
      else
        update!(
          preview_build_status: :preview_failed,
          preview_build_error_message: error.to_s.truncate(2_000),
          preview_build_retry_at: at + preview_build_retry_delay,
          preview_build_claim_token: nil,
          preview_build_completed_at: at,
          preview_build_reconciled_at: nil
        )
      end
    end

    true
  end

  def mark_preview_build_enqueue_failed!(error)
    with_lock do
      reload
      return false unless preview_queued?

      update!(
        preview_build_error_message: error.to_s.truncate(2_000),
        preview_build_reconciled_at: nil
      )
    end

    true
  end

  def repair_preview_build_from_artifact!(site_path:, artifact_claim_token:, at: Time.current)
    repaired = false

    with_lock do
      reload
      if preview_running? && preview_build_claim_token != artifact_claim_token
        return false
      end

      update!(
        markdown_entry_path: site_path,
        site_build_path: site_path,
        preview_build_status: :preview_succeeded,
        preview_build_error_message: nil,
        preview_build_retry_at: nil,
        preview_build_claim_token: nil,
        preview_build_completed_at: at,
        preview_build_reconciled_at: at
      )
      repaired = true
    end

    broadcast_preview_ready if repaired
    repaired
  end

  def preview_build_artifact_consistent?(artifact)
    preview_succeeded? &&
      markdown_entry_path == artifact.site_path &&
      site_build_path == artifact.site_path
  end

  def preview_build_queue_stale?(at: Time.current)
    preview_queued? && (preview_build_enqueued_at.blank? || preview_build_enqueued_at <= at - PREVIEW_BUILD_QUEUE_STALE_AFTER)
  end

  def preview_build_running_stale?(at: Time.current)
    preview_running? && (preview_build_started_at.blank? || preview_build_started_at <= at - PREVIEW_BUILD_RUNNING_STALE_AFTER)
  end

  def preview_build_retry_due?(at: Time.current)
    preview_failed? && (preview_build_retry_at.blank? || preview_build_retry_at <= at)
  end

  def preview_build_attempts_exhausted?
    preview_build_attempt_count >= PREVIEW_BUILD_MAX_ATTEMPTS
  end

  def mark_preview_build_reconciled!(at: Time.current)
    update_columns(preview_build_reconciled_at: at, updated_at: at)
  end

  def preview_build_retry_delay
    index = [[preview_build_attempt_count - 1, 0].max, PREVIEW_BUILD_RETRY_DELAYS.length - 1].min
    PREVIEW_BUILD_RETRY_DELAYS.fetch(index)
  end

  def transition_preview_build_to_abandoned!(at:, error:)
    update!(
      preview_build_status: :preview_abandoned,
      preview_build_error_message: error.to_s.truncate(2_000),
      preview_build_retry_at: nil,
      preview_build_claim_token: nil,
      preview_build_completed_at: at,
      preview_build_reconciled_at: nil
    )
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
    value = value.sub(/\A(?:index|README)\.(?:md|markdown|mdx)\z/i, "index")
    value = value.sub(%r{/(?:index|README)\.(?:md|markdown|mdx)\z}i, "")
    value = value.sub(/\.(md|markdown|mdx)\z/i, "")
    value = value.delete_suffix("/index.html")
    value = value.delete_suffix(".html")
    value.presence || "index"
  end

  def self.search_text_for(*values)
    values.flatten.compact.join("\n").unicode_normalize(:nfkc).squish.presence
  end

  private

  PREVIEW_BUILD_FIELDS = %w[
    preview_build_status
    preview_build_reason
    preview_build_error_message
    preview_build_attempt_count
    preview_build_attempted_at
    preview_build_enqueued_at
    preview_build_started_at
    preview_build_retry_at
    preview_build_claim_token
    preview_build_completed_at
    preview_build_reconciled_at
    site_build_path
    markdown_entry_path
  ].freeze

  def preview_build_only_change?
    (previous_changes.keys - PREVIEW_BUILD_FIELDS - %w[updated_at]).empty?
  end

  def broadcast_preview_ready
    broadcast_refresh_later_to self, :preview
  end

  def normalize_search_body_text
    self.search_body_text = DocumentVersion.search_text_for(search_body_text)
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

  def published_status_transition?
    previous_changes.key?("status") && published?
  end

  def promote_as_latest_version
    return unless published?
    return if document.blank?

    document.update_column(:latest_version_id, id) if document.latest_version_id != id
  end
end
