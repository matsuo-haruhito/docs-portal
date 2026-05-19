class DocumentPathHistoryResolver
  Result = Data.define(:status, :requested_path, :canonical_path, :canonical_version, :matched_version) do
    def canonical?
      status == :canonical
    end

    def moved?
      status == :moved
    end

    def missing?
      status == :missing
    end
  end

  def initialize(document:, requested_site_path:, canonical_version: nil, candidate_versions: nil)
    @document = document
    @requested_site_path = requested_site_path
    @canonical_version = canonical_version || document.latest_version
    @candidate_versions = candidate_versions
  end

  def call
    return missing_result unless canonical_version

    requested = requested_site_path.presence || canonical_version.html_view_site_path
    canonical_path = canonical_version.html_view_site_path
    normalized_requested = normalize(requested)
    normalized_canonical = canonical_version.normalized_html_view_site_path

    return canonical_result(requested:, canonical_path:) if path_under?(normalized_requested, normalized_canonical)

    if (matched_version = matched_metadata_version(normalized_requested))
      return moved_result(requested:, canonical_path:, matched_version:)
    end

    if (matched_version = matched_historical_version(normalized_requested))
      suffix = suffix_under(normalized_requested, matched_version.normalized_html_view_site_path)
      return moved_result(
        requested:,
        canonical_path: join_site_path(canonical_path, suffix),
        matched_version:
      )
    end

    missing_result(requested:, canonical_path:)
  end

  private

  attr_reader :document, :requested_site_path, :canonical_version, :candidate_versions

  def candidate_versions_list
    @candidate_versions_list ||= Array(candidate_versions || document.document_versions).compact
  end

  def matched_metadata_version(normalized_requested)
    candidate_versions_list
      .select { |version| metadata_site_paths_for(version).any? { |path| normalize(path) == normalized_requested } }
      .max_by { |version| [version.created_at || Time.zone.at(0), version.id || 0] }
  end

  def metadata_site_paths_for(version)
    DocumentPathHistoryMetadata.new(version).call.site_paths
  end

  def matched_historical_version(normalized_requested)
    candidate_versions_list
      .reject { |version| version == canonical_version }
      .select { |version| version.html_view_site_path.present? }
      .select { |version| path_under?(normalized_requested, version.normalized_html_view_site_path) }
      .max_by { |version| version.normalized_html_view_site_path.length }
  end

  def path_under?(normalized_path, normalized_base)
    normalized_path == normalized_base || normalized_path.start_with?("#{normalized_base}/")
  end

  def suffix_under(normalized_path, normalized_base)
    return "" if normalized_path == normalized_base

    normalized_path.delete_prefix("#{normalized_base}/")
  end

  def join_site_path(base, suffix)
    return base if suffix.blank?

    [base.to_s.delete_suffix("/"), suffix.to_s.delete_prefix("/")].join("/")
  end

  def normalize(path)
    DocumentVersion.normalize_site_page_path(path)
  end

  def canonical_result(requested:, canonical_path:)
    Result.new(
      status: :canonical,
      requested_path: requested,
      canonical_path:,
      canonical_version:,
      matched_version: canonical_version
    )
  end

  def moved_result(requested:, canonical_path:, matched_version:)
    Result.new(
      status: :moved,
      requested_path: requested,
      canonical_path:,
      canonical_version:,
      matched_version:
    )
  end

  def missing_result(requested: requested_site_path, canonical_path: canonical_version&.html_view_site_path)
    Result.new(
      status: :missing,
      requested_path: requested,
      canonical_path:,
      canonical_version:,
      matched_version: nil
    )
  end
end
