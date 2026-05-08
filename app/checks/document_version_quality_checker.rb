class DocumentVersionQualityChecker
  Check = Data.define(:key, :severity, :message, :detail) do
    def error?
      severity == :error
    end

    def warning?
      severity == :warning
    end

    def info?
      severity == :info
    end
  end

  Result = Data.define(:document_version, :checks) do
    def errors
      checks.select(&:error?)
    end

    def warnings
      checks.select(&:warning?)
    end

    def infos
      checks.select(&:info?)
    end

    def pass?
      errors.empty?
    end
  end

  INTERNAL_ONLY_PATTERNS = [
    /社内(?:限|向|用|秘)/,
    /internal[\s_-]*only/i,
    /confidential/i
  ].freeze
  MARKDOWN_REFERENCE_PATTERN = /
    (!)?             # image marker
    \[[^\]]*\]
    \(
      \s*
      (<?[^)\s>]+>?) # target
      [^)]*
    \)
  /x.freeze
  IMAGE_EXTENSIONS = %w[
    .png
    .jpg
    .jpeg
    .gif
    .svg
    .webp
    .bmp
  ].freeze
  MARKDOWN_EXTENSIONS = %w[
    .md
    .markdown
  ].freeze

  def initialize(document_version)
    @document_version = document_version
    @document = document_version.document
  end

  def call
    Result.new(document_version:, checks: [
      *DocumentVersionQuality::MetadataChecks.new(document_version:, check_class: Check).call,
      *DocumentVersionQuality::DocumentFileChecks.new(document_version:, check_class: Check).call,
      *DocumentVersionQuality::MarkdownReferenceChecks.new(document_version:, check_class: Check).call
    ].compact)
  end

  private

  attr_reader :document_version
end
