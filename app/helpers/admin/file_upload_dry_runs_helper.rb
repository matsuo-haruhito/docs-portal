module Admin::FileUploadDryRunsHelper
  def file_upload_source_path_preview(source_path)
    value = source_path.to_s.strip
    return "-" if value.blank?

    filename = value.tr("\\", "/").split("/").reject(&:blank?).last
    display_name = filename.presence || "source pathあり"

    "#{display_name}（フルパスは非表示）"
  end
end
