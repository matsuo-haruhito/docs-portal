require "digest"
require "tempfile"
require "zip"

class Api::Internal::FileUploadsController < Api::Internal::ZipUploadsController
  UploadedZip = Data.define(:tempfile, :original_filename, :content_type) do
    def read(*args)
      tempfile.read(*args)
    end

    def rewind
      tempfile.rewind
    end
  end

  private

  def render_validation_result
    staged = stage_uploaded_file
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
        file_upload_preview: file_upload_preview(staged)
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

  def stage_uploaded_file
    stager.call
  ensure
    close_zipped_upload!
  end

  def confirmed_dry_run
    return @confirmed_dry_run if defined?(@confirmed_dry_run)

    public_id = params[:import_dry_run_id].to_s
    @confirmed_dry_run =
      if public_id.present?
        ImportDryRun.find_by!(public_id: public_id, status: :analyzed, import_mode: :manual_upload)
      end
  end

  def ensure_zip_dry_run!
    raise ApplicationError::BadRequest, "import_dry_run_id is required for file upload execution" unless confirmed_dry_run
    raise ApplicationError::BadRequest, "file upload dry-run artifact is missing" if confirmed_dry_run.result_json["artifact_root"].blank? || confirmed_dry_run.result_json["manifest_path"].blank?
  end

  def stager
    @stager ||= ZipImportStager.new(
      uploaded_file: zipped_upload,
      project: project,
      actor: actor,
      source_repo: source_name,
      source_branch: relative_path,
      source_commit_hash: params[:source_commit_hash].presence || uploaded_file_hash,
      version_label: version_label,
      status: params[:status]
    )
  end

  def file_upload_preview(staged)
    {
      source_name: source_name,
      relative_path: relative_path,
      source_path: params[:source_path].to_s.presence,
      file_size: uploaded_file_size,
      source_commit_hash: staged.manifest["source_commit_hash"],
      version_label: version_label,
      zip_import_preview: staged.manifest["zip_import_preview"]
    }
  end

  def zipped_upload
    @zipped_upload ||= begin
      zip_tempfile = Tempfile.new(["file-upload", ".zip"])
      zip_tempfile.binmode
      zip_path = zip_tempfile.path
      zip_tempfile.close

      Zip::File.open(zip_path, create: true) do |zip_file|
        zip_file.add(relative_path, upload_file_path)
      end

      @zipped_upload_tempfile = zip_tempfile
      UploadedZip.new(
        tempfile: File.open(zip_path, "rb"),
        original_filename: "file_upload.zip",
        content_type: "application/zip"
      )
    end
  end

  def close_zipped_upload!
    @zipped_upload&.tempfile&.close unless @zipped_upload&.tempfile&.closed?
    @zipped_upload_tempfile&.close!
  end

  def upload_file
    @upload_file ||= params.require(:file).tap do |file|
      unless file.respond_to?(:tempfile) && file.tempfile.respond_to?(:path)
        raise ApplicationError::BadRequest, "file must be a multipart upload"
      end
    end
  end

  def upload_file_path
    upload_file.tempfile.path
  end

  def uploaded_file_hash
    @uploaded_file_hash ||= Digest::SHA256.file(upload_file_path).hexdigest
  end

  def uploaded_file_size
    @uploaded_file_size ||= File.size(upload_file_path)
  end

  def source_name
    @source_name ||= params[:source_name].presence || "file_upload"
  end

  def version_label
    @version_label ||= params[:version_label].presence || default_version_label
  end

  def default_version_label
    @default_version_label ||= "file-#{Time.current.strftime('%Y%m%d%H%M%S')}-#{uploaded_file_hash.first(8)}"
  end

  def relative_path
    @relative_path ||= begin
      value = params[:relative_path].presence || upload_file.original_filename.to_s
      normalized = value.tr("\\", "/")
      raise ApplicationError::BadRequest, "relative_path is invalid" if unsafe_relative_path?(normalized)

      Pathname(normalized.delete_prefix("/")).cleanpath.to_s
    end
  end

  def unsafe_relative_path?(path)
    segments = path.split("/")

    path.blank? ||
      path == "." ||
      path == ".." ||
      path.start_with?("/") ||
      path.match?(%r{\A[A-Za-z]:/}) ||
      path.include?("\0") ||
      segments.include?("..")
  end
end
