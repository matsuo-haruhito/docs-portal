require "tempfile"
require "zip"

class Api::Internal::ManualUploadsController < Api::Internal::ZipUploadsController
  UploadedZip = Data.define(:tempfile, :original_filename)

  private

  def render_validation_result
    staged = stager.call
    result = ImportManifestDryRun.new(manifest: staged.manifest).call
    dry_run = ImportDryRun.create!(
      import_mode: :manual_upload,
      project: project,
      created_by: actor,
      source_commit_hash: staged.manifest["source_commit_hash"],
      summary_json: result[:summary],
      result_json: result.merge(
        artifact_root: staged.artifact_root.to_s,
        manifest_path: staged.manifest_path.to_s,
        file_upload_preview: {
          relative_path: relative_path,
          source_path: params[:source_path].to_s.presence,
          zip_import_preview: staged.manifest["zip_import_preview"]
        }
      ),
      warnings_json: result[:warnings] + Array(staged.manifest.dig("zip_import_preview", "warnings")),
      errors_json: result[:errors]
    )

    render json: result.merge(
      dry_run_id: dry_run.public_id,
      status: dry_run.status,
      expires_at: dry_run.expires_at,
      file_upload_preview: dry_run.result_json["file_upload_preview"]
    ), status: :created
  end

  def confirmed_dry_run
    return @confirmed_dry_run if defined?(@confirmed_dry_run)

    public_id = params[:import_dry_run_id].to_s
    @confirmed_dry_run =
      if public_id.present?
        ImportDryRun.find_by!(public_id:, status: :analyzed, import_mode: :manual_upload)
      end
  end

  def ensure_zip_dry_run!
    raise ApplicationError::BadRequest, "import_dry_run_id is required for file upload execution" unless confirmed_dry_run
    raise ApplicationError::BadRequest, "file upload dry-run artifact is missing" if confirmed_dry_run.result_json["artifact_root"].blank? || confirmed_dry_run.result_json["manifest_path"].blank?
  end

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
      raise ApplicationError::BadRequest, "relative_path is invalid" if unsafe_relative_path?(path)

      path
    end
  end

  def unsafe_relative_path?(path)
    path.blank? ||
      path == "." ||
      path == ".." ||
      path.start_with?("/") ||
      path.start_with?("../") ||
      path.include?("/../") ||
      path.match?(%r{\A[A-Za-z]:/}) ||
      path.include?("\0")
  end
end
