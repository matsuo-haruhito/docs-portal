module DocumentExport
  class FileSelector
    def initialize(user:, include_markdown_sources:, include_attachments:, pdf_only:)
      @user = user
      @include_markdown_sources = include_markdown_sources
      @include_attachments = include_attachments
      @pdf_only = pdf_only
    end

    def call(files)
      Array(files).select { downloadable_file?(_1) }
    end

    def markdown_source_file?(file)
      file.effective_content_type.start_with?("text/markdown")
    end

    def pdf_file?(file)
      file.effective_content_type.start_with?("application/pdf") || file.file_name.to_s.downcase.end_with?(".pdf")
    end

    private

    attr_reader :user, :include_markdown_sources, :include_attachments, :pdf_only

    def downloadable_file?(file)
      return false unless file.downloadable_by?(user)
      return false unless include_file?(file)
      return false unless File.file?(file.absolute_path)

      true
    end

    def include_file?(file)
      return false if pdf_only && !pdf_file?(file)
      return false if markdown_source_file?(file) && !include_markdown_sources
      return false if !markdown_source_file?(file) && !include_attachments

      true
    end
  end
end
