module Admin::MissingDocumentFilesHelper
  def missing_document_file_expected_path_preview(file)
    normalized_key = file.storage_key.to_s.tr("\\", "/").delete_prefix("/")
    relative_path = Pathname.new(normalized_key.presence || "document-file").cleanpath.to_s

    if relative_path.blank? || relative_path == "." || relative_path == ".." || relative_path.start_with?("../")
      return "storage/document_files/[invalid storage key]"
    end

    File.join("storage", "document_files", relative_path)
  end

  def missing_document_file_project_option_label(project)
    [project.code, project.name].compact_blank.join(" / ")
  end

  def missing_document_file_project_selected_option(project)
    return nil if project.blank?

    { value: project.id, text: missing_document_file_project_option_label(project) }
  end
end
