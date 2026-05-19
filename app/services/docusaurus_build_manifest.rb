require "json"

class DocusaurusBuildManifest
  MANIFEST_FILE_NAMES = %w[
    .docs-portal-build-manifest.json
    docs-portal-build-manifest.json
    build-manifest.json
  ].freeze

  Warning = Data.define(:code, :message, :detail)
  Result = Data.define(:source_path, :metadata, :warnings) do
    def source_file?
      source_path.present?
    end

    def valid?
      warnings.empty?
    end

    def profile
      metadata["profile"]
    end

    def source_commit
      metadata["source_commit"]
    end

    def built_at
      metadata["built_at"]
    end

    def entry_path
      metadata["entry_path"]
    end

    def build_result
      metadata["build_result"]
    end
  end

  def initialize(document_version, expected_profile: Rails.env)
    @document_version = document_version
    @expected_profile = expected_profile.to_s.presence
  end

  def call
    return Result.new(source_path: nil, metadata: {}, warnings: []) if document_version.site_build_path.blank?

    path = manifest_path
    return Result.new(source_path: nil, metadata: {}, warnings: [manifest_missing_warning]) unless path

    metadata = read_metadata(path)
    Result.new(source_path: relative_source_path(path), metadata:, warnings: validate_metadata(metadata))
  rescue JSON::ParserError => e
    Result.new(source_path: relative_source_path(path), metadata: {}, warnings: [Warning.new(code: :invalid_json, message: "Docusaurus build manifest is invalid JSON", detail: e.message)])
  end

  private

  attr_reader :document_version, :expected_profile

  def manifest_path
    candidate_manifest_paths.detect(&:exist?)
  end

  def candidate_manifest_paths
    candidate_directories.flat_map do |directory|
      MANIFEST_FILE_NAMES.map { |file_name| directory.join(file_name) }
    end
  end

  def candidate_directories
    [site_build_absolute_path, document_version.site_root_absolute_path].compact.uniq
  end

  def site_build_absolute_path
    return if document_version.site_build_path.blank?

    document_version.site_root_absolute_path.join(document_version.site_build_path)
  end

  def read_metadata(path)
    parsed = JSON.parse(File.read(path, encoding: "UTF-8"))
    parsed.is_a?(Hash) ? parsed : {}
  end

  def validate_metadata(metadata)
    warnings = []
    warnings << Warning.new(code: :profile_mismatch, message: "Docusaurus build profile does not match", detail: "expected=#{expected_profile} actual=#{metadata['profile']}") if profile_mismatch?(metadata)
    warnings << Warning.new(code: :source_commit_mismatch, message: "Docusaurus build source commit does not match", detail: "expected=#{document_version.source_commit_hash} actual=#{metadata['source_commit']}") if source_commit_mismatch?(metadata)
    warnings << Warning.new(code: :entry_path_mismatch, message: "Docusaurus build entry path does not match", detail: "expected=#{expected_entry_path} actual=#{metadata['entry_path']}") if entry_path_mismatch?(metadata)
    warnings << Warning.new(code: :build_result_failed, message: "Docusaurus build manifest reports an unsuccessful build", detail: metadata["build_result"]) if build_result_failed?(metadata)
    warnings
  end

  def profile_mismatch?(metadata)
    expected_profile.present? && metadata["profile"].present? && metadata["profile"].to_s != expected_profile
  end

  def source_commit_mismatch?(metadata)
    document_version.source_commit_hash.present? && metadata["source_commit"].present? && metadata["source_commit"].to_s != document_version.source_commit_hash
  end

  def entry_path_mismatch?(metadata)
    metadata["entry_path"].present? && normalize_site_path(metadata["entry_path"]) != normalize_site_path(expected_entry_path)
  end

  def build_result_failed?(metadata)
    metadata["build_result"].present? && metadata["build_result"].to_s != "success"
  end

  def expected_entry_path
    document_version.html_view_site_path.presence || document_version.site_build_path
  end

  def normalize_site_path(path)
    DocumentVersion.normalize_site_page_path(path)
  end

  def manifest_missing_warning
    Warning.new(code: :manifest_missing, message: "Docusaurus build manifest is missing", detail: expected_manifest_location)
  end

  def expected_manifest_location
    site_build_absolute_path&.join(MANIFEST_FILE_NAMES.first)&.relative_path_from(document_version.site_root_absolute_path)&.to_s
  end

  def relative_source_path(path)
    path&.relative_path_from(document_version.site_root_absolute_path)&.to_s
  end
end
