class DocumentFileContentDisposition
  def initialize(document_file, disposition: "attachment")
    @document_file = document_file
    @disposition = disposition
  end

  def header
    ContentDispositionFilename.new(document_file.file_name, disposition:).header
  end

  def inline_header
    self.class.new(document_file, disposition: "inline").header
  end

  def attachment_header
    self.class.new(document_file, disposition: "attachment").header
  end

  private

  attr_reader :document_file, :disposition
end
