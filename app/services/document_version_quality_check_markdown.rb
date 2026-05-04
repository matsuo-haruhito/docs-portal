class DocumentVersionQualityCheckMarkdown
  SEVERITY_LABELS = {
    error: "Error",
    warning: "Warning",
    info: "Info"
  }.freeze

  def initialize(result)
    @result = result
  end

  def call
    [
      title_section,
      "",
      summary_section,
      "",
      checks_section
    ].join("\n").strip + "\n"
  end

  private

  attr_reader :result

  def document_version
    result.document_version
  end

  def document
    document_version.document
  end

  def title_section
    [
      "# Quality check: #{document.title}",
      "",
      "- document: #{document.public_id}",
      "- version: #{document_version.version_label}",
      "- status: #{document_version.status}",
      "- result: #{result.pass? ? 'pass' : 'fail'}"
    ].join("\n")
  end

  def summary_section
    [
      "## Summary",
      "",
      "- errors: #{result.errors.size}",
      "- warnings: #{result.warnings.size}",
      "- infos: #{result.infos.size}"
    ].join("\n")
  end

  def checks_section
    return "## Checks\n\nNo checks." if result.checks.empty?

    [
      "## Checks",
      "",
      *result.checks.map { check_line(_1) }
    ].join("\n")
  end

  def check_line(check)
    label = SEVERITY_LABELS.fetch(check.severity)
    detail = check.detail.present? ? " — #{check.detail}" : ""
    "- **#{label}** `#{check.key}`: #{check.message}#{detail}"
  end
end
