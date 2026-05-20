class DocumentPathHistorySummary
  Entry = Data.define(:version, :path)
  Result = Data.define(:canonical_path, :entries) do
    def present?
      entries.any?
    end

    def paths
      entries.map(&:path)
    end
  end

  def initialize(document_version, candidate_versions: nil)
    @document_version = document_version
    @candidate_versions = candidate_versions
  end

  def call
    Result.new(canonical_path:, entries: historical_entries)
  end

  private

  attr_reader :document_version, :candidate_versions

  def canonical_path
    document_version.html_view_site_path
  end

  def historical_entries
    versions
      .reject { _1 == document_version }
      .filter_map { |version| historical_entry_for(version) }
      .uniq { _1.path }
      .sort_by { [_1.path, _1.version.created_at || Time.zone.at(0)] }
  end

  def historical_entry_for(version)
    path = version.html_view_site_path.presence
    return if path.blank?
    return if DocumentVersion.normalize_site_page_path(path) == document_version.normalized_html_view_site_path

    Entry.new(version:, path:)
  end

  def versions
    @versions ||= Array(candidate_versions || document_version.document.document_versions).compact
  end
end
