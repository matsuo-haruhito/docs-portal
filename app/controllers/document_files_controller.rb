class DocumentFilesController < BaseController
  def show
    file = DocumentFile.find_by!(public_id: params[:public_id])
    require_file_access!(file)

    viewer_plan = viewer_plan_for(file)
    disposition = disposition_for(viewer_plan)
    consent_timing = embedded_request? ? :first_view : :download
    return if require_consent!(target: file, timing: consent_timing)

    return if render_office_preview_for(file, viewer_plan, disposition)

    file_path = file.absolute_path

    unless File.exist?(file_path)
      render_file_not_found
      return
    end

    record_file_access_log(file)

    return if render_inline_preview_for(file, viewer_plan, disposition)
    return if render_embedded_html_preview_for(file, disposition)

    send_document_file(file, file_path:, disposition:)
  end

  def asset
    owner_file = DocumentFile.find_by!(public_id: params[:public_id])
    require_file_access!(owner_file)

    asset_file = embedded_asset_file_for(owner_file, params[:asset_path])
    unless asset_file&.deliverable_after_scan?(current_user)
      render_file_not_found
      return
    end

    return if render_embedded_html_asset_for(owner_file, asset_file)

    send_document_file(asset_file, file_path: asset_file.absolute_path, disposition: "inline")
  end

  private

  def require_file_access!(file)
    if embedded_request? || action_name == "asset"
      require_document_version_view_access!(file.document_version)
      raise ApplicationError::Forbidden unless file.deliverable_after_scan?(current_user)
    else
      require_document_file_download_access!(file)
    end
  end

  def record_file_access_log(file)
    if embedded_request?
      record_file_view_access_log(file)
    else
      record_download_access_log(file)
    end
  end

  def disposition_for(viewer_plan)
    case params[:disposition]
    when "inline"
      viewer_plan.inline_disposition? ? "inline" : "attachment"
    when "download"
      "attachment"
    else
      viewer_plan.inline_disposition? ? "inline" : "attachment"
    end
  end

  def viewer_plan_for(file)
    DocumentFileViewerPlan.new(file:, user: current_user).call
  end

  def inline_preview_request?(disposition)
    disposition == "inline" && !embedded_request?
  end

  def inline_preview_kind?(viewer_plan, disposition, *viewer_kinds)
    inline_preview_request?(disposition) && viewer_plan.viewer_kind.in?(viewer_kinds)
  end

  def text_preview_request?(file, disposition)
    inline_preview_request?(disposition) && file.text_previewable?
  end

  def office_preview_request?(viewer_plan, disposition)
    disposition == "inline" && embedded_request? && viewer_plan.viewer_kind == :office
  end

  def render_office_preview_for(file, viewer_plan, disposition)
    return false unless office_preview_request?(viewer_plan, disposition)

    preview_url = office_preview_url_for(file)
    record_file_access_log(file)
    redirect_to preview_url, allow_other_host: true
    true
  rescue DocumentFileOfficePreview::FileTooLargeError
    record_file_access_log(file)
    @document_file = file
    @download_available = viewer_plan.downloadable?
    render :office_preview_unavailable, status: :ok
    true
  rescue DocumentFileOfficePreview::Error, MicrosoftGraphClient::Error => e
    render plain: "Office preview is not available: #{e.message}", status: :bad_gateway
    true
  end

  def render_inline_preview_for(file, viewer_plan, disposition)
    if inline_preview_kind?(viewer_plan, disposition, :pdf)
      render_inline_preview(:show_pdf_preview) { prepare_inline_preview!(file, disposition:) }
    elsif inline_preview_kind?(viewer_plan, disposition, :image)
      render_inline_preview(:show_image_preview) { prepare_inline_preview!(file, disposition:) }
    elsif inline_preview_kind?(viewer_plan, disposition, :csv)
      render_inline_preview(:show_csv_preview) { prepare_csv_preview!(file, disposition:) }
    elsif inline_preview_kind?(viewer_plan, disposition, :json, :yaml)
      render_inline_preview(:show_structured_preview) do
        prepare_structured_preview!(file, viewer_kind: viewer_plan.viewer_kind, disposition:)
      end
    elsif inline_preview_kind?(viewer_plan, disposition, :archive)
      render_inline_preview(:show_archive_preview) { prepare_archive_preview!(file, disposition:) }
    elsif text_preview_request?(file, disposition)
      render_inline_preview(:show_text_preview) { prepare_text_preview!(file, disposition:) }
    else
      return false
    end

    true
  end

  def render_embedded_html_preview_for(file, disposition)
    return false unless disposition == "inline" && embedded_request? && html_file?(file)

    set_content_disposition_header(file, disposition: "inline")
    render html: embedded_html_for(file, file.absolute_path).html_safe, content_type: "text/html"
    true
  end

  def render_embedded_html_asset_for(owner_file, asset_file)
    return false unless html_file?(asset_file)

    set_content_disposition_header(asset_file, disposition: "inline")
    render html: embedded_html_for(owner_file, asset_file.absolute_path, current_tree_path: asset_file.tree_path).html_safe, content_type: "text/html"
    true
  end

  def render_inline_preview(template)
    yield
    render template
  end

  def render_file_not_found
    render plain: "File not found", status: :not_found
  end

  def prepare_inline_preview!(file, disposition:)
    set_content_disposition_header(file, disposition:)
    assign_preview_context(file)
  end

  def prepare_csv_preview!(file, disposition:)
    prepare_inline_preview!(file, disposition:)
    @csv_preview = DocumentFileCsvPreview.new(file:).call
  end

  def prepare_structured_preview!(file, viewer_kind:, disposition:)
    prepare_inline_preview!(file, disposition:)
    @structured_preview = DocumentFileStructuredPreview.new(file:, viewer_kind:).call
    @structured_language = viewer_kind.to_s.upcase
  end

  def prepare_archive_preview!(file, disposition:)
    prepare_inline_preview!(file, disposition:)
    @archive_preview = DocumentFileArchivePreview.new(file:).call
  end

  def prepare_text_preview!(file, disposition:)
    prepare_inline_preview!(file, disposition:)
    @text_preview = DocumentFileTextPreview.new(file:).call
  end

  def assign_preview_context(file)
    @document_file = file
    @document_version = file.document_version
    @document = @document_version.document
    @project = @document.project
  end

  def office_preview_url_for(file)
    DocumentFileOfficePreview.new(file:, user: current_user).url
  end

  def send_document_file(file, file_path:, disposition:)
    send_file(
      file_path,
      disposition:,
      type: file.effective_content_type
    )
    set_content_disposition_header(file, disposition:)
  end

  def set_content_disposition_header(file, disposition:)
    response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
  end

  def embedded_html_for(owner_file, file_path, current_tree_path: owner_file.tree_path)
    html = File.read(file_path, encoding: "UTF-8")
    base_tag = %(<base href="#{ERB::Util.html_escape(document_file_asset_base_path(owner_file, current_tree_path:))}/">)

    if html.match?(%r{<head[\s>]}i)
      html.sub(%r{(<head[^>]*>)}i, "\\1\n#{base_tag}")
    else
      "#{base_tag}\n#{html}"
    end
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    File.binread(file_path)
  end

  def document_file_asset_base_path(file, current_tree_path: file.tree_path)
    current_directory = File.dirname(current_tree_path.to_s)
    current_directory = nil if current_directory == "."
    asset_path = [current_directory, "."].compact_blank.join("/")

    asset_document_file_path(file, asset_path:)
      .sub(%r{/\.\z}, "")
  end

  def embedded_asset_file_for(owner_file, requested_asset_path)
    normalized_asset_path = normalize_asset_path(requested_asset_path)
    return if normalized_asset_path.blank?

    owner_file.document_version.document_files.detect do |candidate|
      normalize_asset_path(candidate.tree_path) == normalized_asset_path
    end
  end

  def normalize_asset_path(value)
    path = value.to_s.tr("\\", "/").delete_prefix("/")
    normalized = Pathname.new(path.presence || ".").cleanpath.to_s
    return if normalized.blank? || normalized == "." || normalized == ".." || normalized.start_with?("../")

    normalized
  end

  def html_file?(file)
    file.effective_content_type.start_with?("text/html") || File.extname(file.file_name.to_s).downcase.in?(%w[.html .htm])
  end

  def embedded_request?
    ActiveModel::Type::Boolean.new.cast(params[:embedded])
  end
end
