class DocumentFileViewerPlan
  Result = Data.define(
    :viewer_kind,
    :label,
    :previewable,
    :downloadable,
    :inline_disposition,
    :reason
  ) do
    def previewable?
      previewable
    end

    def downloadable?
      downloadable
    end

    def inline_disposition?
      inline_disposition
    end
  end

  MARKDOWN_EXTENSIONS = %w[.md .markdown .mdx].freeze
  HTML_EXTENSIONS = %w[.html .htm].freeze
  CSV_EXTENSIONS = %w[.csv .tsv].freeze
  JSON_EXTENSIONS = %w[.json].freeze
  YAML_EXTENSIONS = %w[.yaml .yml].freeze
  TEXT_EXTENSIONS = %w[.txt .log].freeze
  ARCHIVE_EXTENSIONS = %w[.zip .tar .gz .tgz].freeze

  def initialize(file:, user:)
    @file = file
    @user = user
  end

  def call
    Result.new(
      viewer_kind:,
      label:,
      previewable: previewable?,
      downloadable: file.downloadable_by?(user),
      inline_disposition: inline_disposition?,
      reason: reason
    )
  end

  private

  attr_reader :file, :user

  def viewer_kind
    return :markdown if markdown?
    return :html if html?
    return :pdf if pdf?
    return :office if office?
    return :csv if csv?
    return :json if json?
    return :yaml if yaml?
    return :image if image?
    return :text if text?
    return :archive if archive?

    :download_only
  end

  def label
    case viewer_kind
    when :markdown
      "Markdown preview"
    when :html
      "HTML preview"
    when :pdf
      "PDF preview"
    when :office
      "Office preview"
    when :csv
      "Table preview"
    when :json
      "JSON preview"
    when :yaml
      "YAML preview"
    when :image
      "Image preview"
    when :text
      "Text preview"
    when :archive
      zip_archive? ? "ZIP preview" : "Archive"
    else
      "Download only"
    end
  end

  def previewable?
    return false if file.blocked_by_scan? && !user&.internal?

    case viewer_kind
    when :markdown, :html, :pdf, :office, :json, :yaml, :image, :text
      true
    when :csv
      file.text_previewable?
    when :archive
      zip_archive?
    else
      false
    end
  end

  def inline_disposition?
    previewable? && (file.inline_disposition? || file.office_previewable? || zip_archive?)
  end

  def reason
    return "ウイルススキャン完了後に表示できます" if file.blocked_by_scan? && !user&.internal?
    return "ZIP以外の圧縮ファイル preview は未対応です" if unsupported_archive?
    return "ブラウザ preview は未対応です" unless previewable?

    nil
  end

  def extension
    File.extname(file.file_name.to_s).downcase
  end

  def content_type
    file.effective_content_type.delete_suffix("; charset=utf-8")
  end

  def raw_content_type
    file.content_type.to_s.delete_suffix("; charset=utf-8")
  end

  def markdown?
    extension.in?(MARKDOWN_EXTENSIONS) || content_type == "text/markdown"
  end

  def html?
    extension.in?(HTML_EXTENSIONS) || content_type == "text/html"
  end

  def pdf?
    content_type == "application/pdf" || extension == ".pdf"
  end

  def office?
    file.office_previewable?
  end

  def csv?
    extension.in?(CSV_EXTENSIONS) ||
      content_type.in?(%w[text/csv text/tab-separated-values]) ||
      raw_content_type.in?(%w[text/csv text/tab-separated-values])
  end

  def json?
    extension.in?(JSON_EXTENSIONS) || content_type == "application/json"
  end

  def yaml?
    extension.in?(YAML_EXTENSIONS) || content_type.in?(%w[text/yaml application/x-yaml])
  end

  def image?
    content_type.start_with?("image/")
  end

  def text?
    extension.in?(TEXT_EXTENSIONS) || content_type.start_with?("text/")
  end

  def archive?
    extension.in?(ARCHIVE_EXTENSIONS)
  end

  def zip_archive?
    extension == ".zip" || content_type == "application/zip"
  end

  def unsupported_archive?
    archive? && !zip_archive?
  end
end
