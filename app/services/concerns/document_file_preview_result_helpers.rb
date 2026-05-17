module DocumentFilePreviewResultHelpers
  def truncated?
    respond_to?(:truncated) && truncated
  end

  def error?
    respond_to?(:error) && error.present?
  end
end
