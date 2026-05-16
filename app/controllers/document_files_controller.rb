class DocumentFilesController < BaseController
  def show
    file = DocumentFile.find_by!(public_id: params[:public_id])
    require_file_access!(file)

    viewer_plan = viewer_plan_for(file)
    disposition = disposition_for(viewer_plan)
    consent_timing = embedded_request? ? :first_view : :download
    return if require_consent!(target: file, timing: consent_timing)

    if disposition == "inline" && embedded_request? && viewer_plan.viewer_kind == :office
      begin
        preview_url = office_preview_url_for(file)
        record_file_access_log(file)
        redirect_to preview_url, allow_other_host: true
        return
      rescue DocumentFileOfficePreview::FileTooLargeError
        record_file_access_log(file)
        @document_file = file
        @download_available = viewer_plan.downloadable?
        render :office_preview_unavailable, status: :ok
        return
      rescue DocumentFileOfficePreview::Error, MicrosoftGraphClient::Error => e
        render plain: "Office preview is not available: #{e.message}", status: :bad_gateway
        return
      end
    end

    file_path = file.absolute_path

    unless File.exist?(file_path)
      render plain: "File not found", status: :not_found
      return
    end

    record_file_access_log(file)

    if disposition == "inline" && viewer_plan.viewer_kind == :csv && !embedded_request?
      response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
      assign_preview_context(file)
      @csv_preview = DocumentFileCsvPreview.new(file:).call
      render :show_csv_preview
      return
    end

    if disposition == "inline" && file.text_previewable? && !embedded_request?
      response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
      assign_preview_context(file)
      @preview_lines = File.read(file_path, encoding: "UTF-8").lines(chomp: true)
      render :show_text_preview
      return
    end

    if disposition == "inline" && embedded_request? && html_file?(file)
      response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
      render html: embedded_html_for(file, file.absolute_path).html_safe, content_type: "text/html"
      return
    end

    send_file(
      file_path,
      disposition:,
      type: file.effective_content_type
    )
    response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
  end

  def asset
    owner_file = DocumentFile.find_by!(public_id: params[:public_id])
    require_file_access!(owner_file)

    asset_file = embedded_asset_file_for(owner_file, params[:asset_path])
    unless asset_file&.deliverable_after_scan?(current_user)
      render plain: "File not found", status: :not_found
      return
    end

    if html_file?(asset_file)
      response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(asset_file, disposition: "inline").header
      render html: embedded_html_for(owner_file, asset_file.absolute_path, current_tree_path: asset_file.tree_path).html_safe, content_type: "text/html"
      return
    end

    send_file(
      asset_file.absolute_path,
      disposition: "inline",
      type: asset_file.effective_content_type
    )
    response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(asset_file, disposition: "inline").header
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

  def assign_preview_context(file)
    @document_file = file
    @document_version = file.document_version
    @document = @document_version.document
    @project = @document.project
  end

  def office_preview_url_for(file)
    DocumentFileOfficePreview.new(file:, user: current_user).url
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
