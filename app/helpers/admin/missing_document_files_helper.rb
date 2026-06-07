module Admin::MissingDocumentFilesHelper
  def missing_document_file_expected_path_preview(file)
    normalized_key = file.storage_key.to_s.tr("\\", "/").delete_prefix("/")
    relative_path = Pathname.new(normalized_key.presence || "document-file").cleanpath.to_s

    if relative_path.blank? || relative_path == "." || relative_path == ".." || relative_path.start_with?("../")
      return "storage/document_files/[invalid storage key]"
    end

    File.join("storage", "document_files", relative_path)
  end
end
