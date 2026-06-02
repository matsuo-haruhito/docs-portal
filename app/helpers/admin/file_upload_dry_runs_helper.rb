module Admin::FileUploadDryRunsHelper
  def file_upload_source_path_preview(source_path)
    raw_path = source_path.to_s.strip
    return "-" if raw_path.blank?

    basename = File.basename(raw_path.tr("\\", "/"))
    basename = nil if basename.blank? || basename == "."

    [basename, "フルパスは非表示"].compact.join("（") + (basename.present? ? "）" : "")
  end
end
