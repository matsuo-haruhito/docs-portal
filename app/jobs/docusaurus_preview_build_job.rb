class DocusaurusPreviewBuildJob < ApplicationJob
  queue_as :default

  if respond_to?(:limits_concurrency)
    limits_concurrency to: 1,
      key: ->(version_id) { "docusaurus-preview-build-#{version_id}" },
      duration: 10.minutes
  end

  def perform(version_id)
    version = DocumentVersion.find(version_id)
    return unless markdown_version?(version)

    archive = DocusaurusPreviewArchiveBuilder.new(version).build
    result = DocusaurusRendererClient.new.build(
      archive_file: archive,
      entry_path: version.source_relative_path
    )

    DocusaurusPreviewArtifactInstaller.new(
      version: version,
      archive_path: result.archive_path,
      site_path: result.site_path
    ).install!
  ensure
    archive&.close!
  end

  private

  def markdown_version?(version)
    File.extname(version.source_relative_path.to_s).downcase.in?(%w[.md .markdown .mdx])
  end
end
