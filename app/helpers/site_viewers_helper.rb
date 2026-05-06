module SiteViewersHelper
  def site_viewer_meta_lines(project:, document:, version:)
    [
      "案件: #{project.name}",
      ("文書: #{document.title}" if document.present?),
      "版: #{version.version_label}"
    ].compact
  end
end
