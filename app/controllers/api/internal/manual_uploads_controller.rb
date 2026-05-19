require "tempfile"
require "zip"

class Api::Internal::ManualUploadsController < Api::Internal::ZipUploadsController
  UploadedZip = Data.define(:tempfile, :original_filename)

  private

  def stager
    @stager ||= ZipImportStager.new(
      uploaded_file: zipped_upload,
      project:,
      actor:,
      source_repo: params[:source_name].presence || "file_upload",
      source_branch: params[:source_path].presence || relative_path,
      source_commit_hash: params[:source_commit_hash],
      version_label: params[:version_label],
      status: params[:status]
    )
  end

  def zipped_upload
    @zipped_upload ||= begin
      tempfile = Tempfile.new(["file-upload", ".zip"])
      tempfile.binmode

      Zip::File.open(tempfile.path, create: true) do |zip_file|
        zip_file.add(relative_path, upload_file.tempfile.path)
      end

      tempfile.rewind
      UploadedZip.new(tempfile:, original_filename: "file_upload.zip")
    end
  end

  def upload_file
    params.require(:file)
  end

  def relative_path
    @relative_path ||= begin
      value = params[:relative_path].presence || upload_file.original_filename.to_s
      normalized = value.tr("\\", "/").delete_prefix("/")
      path = Pathname(normalized).cleanpath.to_s
      if path.blank? || path == "." || path == ".." || path.start_with?("../") || path.include?("/../")
        raise ApplicationError::BadRequest, "relative_path is invalid"
      end

      path
    end
  end
end
