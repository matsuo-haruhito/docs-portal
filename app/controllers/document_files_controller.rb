class DocumentFilesController < BaseController
  def show
    file = DocumentFile.find_by!(public_id: params[:public_id])
    require_file_access!(file)

    disposition = disposition_for(file)
    consent_timing = embedded_request? ? :first_view : :download
    return if require_consent!(target: file, timing: consent_timing)

    file_path = file.absolute_path

    unless File.exist?(file_path)
      render plain: "File not found", status: :not_found
      return
    end

    record_file_access_log(file)

    if disposition == "inline" && file.text_previewable? && !embedded_request?
      response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
      @document_file = file
      @document_version = file.document_version
      @document = @document_version.document
      @project = @document.project
      @preview_lines = File.read(file_path, encoding: "UTF-8").lines(chomp: true)
      render :show_text_preview
      return
    end

    if disposition == "inline" && embedded_request? && html_file?(file)
      response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
      render html: embedded_html_for(file, file_path).html_safe, content_type: "text/html"
      return
    end

    send_file(
      file_path,
      disposition:,
      type: file.effective_content_type
    )
    response.headers["Content-Disposition"] = DocumentFileContentDisposition.new(file, disposition:).header
  end

  private

  def require_file_access!(file)
    if embedded_request?
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

  def disposition_for(file)
    case params[:disposition]
    when "inline"
      file.inline_disposition? ? "inline" : "attachment"
    when "download"
      "attachment"
    else
      file.inline_disposition? ? "inline" : "attachment"
    end
  end

  def embedded_html_for(file, file_path)
    html = File.read(file_path, encoding: "UTF-8")
    base_tag = %(<base href="#{ERB::Util.html_escape(document_file_asset_base_url(file))}/">)

    if html.match?(%r{<head[\s>]}i)
      html.sub(%r{(<head[^>]*>)}i, "\\1\n#{base_tag}")
    else
      "#{base_tag}\n#{html}"
    end
  rescue Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
    File.binread(file_path)
  end

  def document_file_asset_base_url(file)
    document_file_url(file, disposition: "inline", embedded: "1", only_path: true)
      .sub(%r{/[^/]*\z}, "")
  end

  def html_file?(file)
    file.effective_content_type.start_with?("text/html") || File.extname(file.file_name.to_s).downcase.in?(%w[.html .htm])
  end

  def embedded_request?
    ActiveModel::Type::Boolean.new.cast(params[:embedded])
  end
end
