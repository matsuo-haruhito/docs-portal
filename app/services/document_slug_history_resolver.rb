class DocumentSlugHistoryResolver
  Result = Data.define(:status, :requested_slug, :canonical_document, :matched_version, :matched_source, :matched_entry) do
    def moved?
      status == :moved
    end

    def missing?
      status == :missing
    end

    def archived?
      status == :archived
    end

    def deleted?
      status == :deleted
    end

    def terminal?
      archived? || deleted?
    end
  end

  def initialize(project:, requested_slug:, candidate_documents: nil)
    @project = project
    @requested_slug = requested_slug.to_s.strip
    @candidate_documents = candidate_documents
  end

  def call
    return missing_result if requested_slug.blank?

    if (status_match = matching_metadata_status_entry)
      return Result.new(
        status: status_match.fetch(:entry).status.to_sym,
        requested_slug:,
        canonical_document: status_match.fetch(:document),
        matched_version: status_match.fetch(:version),
        matched_source: status_match.fetch(:entry).value,
        matched_entry: status_match.fetch(:entry)
      )
    end

    if (match = matching_document_version)
      return Result.new(
        status: :moved,
        requested_slug:,
        canonical_document: match.fetch(:document),
        matched_version: match.fetch(:version),
        matched_source: match.fetch(:source),
        matched_entry: nil
      )
    end

    missing_result
  end

  private

  attr_reader :project, :requested_slug, :candidate_documents

  def matching_metadata_status_entry
    documents.flat_map do |document|
      document.document_versions.map do |version|
        matched_entry = metadata_status_entries_for(version).find { |entry| entry.kind == "slug" && normalize_slug(entry.value) == normalized_requested_slug }
        { document:, version:, entry: matched_entry } if matched_entry.present?
      end
    end.compact.max_by { |match| [match.fetch(:version).created_at || Time.zone.at(0), match.fetch(:version).id || 0] }
  end

  def metadata_status_entries_for(version)
    DocumentPathHistoryMetadata.new(version).call.status_entries
  end

  def matching_document_version
    explicit_match = matching_metadata_document_version
    return explicit_match if explicit_match

    matching_inferred_document_version
  end

  def matching_metadata_document_version
    documents.flat_map do |document|
      document.document_versions.map do |version|
        matched_source = metadata_slug_sources_for(version).find { |source| normalize_slug(source) == normalized_requested_slug }
        { document:, version:, source: matched_source } if matched_source.present?
      end
    end.compact.max_by { |match| [match.fetch(:version).created_at || Time.zone.at(0), match.fetch(:version).id || 0] }
  end

  def matching_inferred_document_version
    documents.flat_map do |document|
      document.document_versions.map do |version|
        matched_source = matched_inferred_source_for(version)
        { document:, version:, source: matched_source } if matched_source.present?
      end
    end.compact.max_by { |match| [match.fetch(:version).created_at || Time.zone.at(0), match.fetch(:version).id || 0] }
  end

  def matched_inferred_source_for(version)
    inferred_slug_sources_for(version).find { |source| normalize_slug(source) == normalized_requested_slug }
  end

  def metadata_slug_sources_for(version)
    DocumentPathHistoryMetadata.new(version).call.slugs
  end

  def inferred_slug_sources_for(version)
    [
      source_file_stem(version.source_file_name),
      source_file_stem(version.source_relative_path),
      path_last_segment(version.source_directory),
      path_last_segment(version.html_view_site_path),
      path_last_segment(version.site_build_path)
    ].compact_blank.uniq
  end

  def source_file_stem(path)
    value = path.to_s.split("/").last
    return if value.blank?

    File.basename(value, File.extname(value))
  end

  def path_last_segment(path)
    path.to_s.tr("\\", "/").split("/").reject(&:blank?).last
  end

  def normalize_slug(value)
    value.to_s
      .unicode_normalize(:nfkc)
      .downcase
      .strip
      .tr("_ ", "--")
      .gsub(/[^a-z0-9\-]+/, "-")
      .gsub(/-+/, "-")
      .delete_prefix("-")
      .delete_suffix("-")
  end

  def normalized_requested_slug
    @normalized_requested_slug ||= normalize_slug(requested_slug)
  end

  def documents
    @documents ||= Array(candidate_documents || project.documents.includes(document_versions: :document_files)).compact.reject { _1.slug == requested_slug }
  end

  def missing_result
    Result.new(status: :missing, requested_slug:, canonical_document: nil, matched_version: nil, matched_source: nil, matched_entry: nil)
  end
end
