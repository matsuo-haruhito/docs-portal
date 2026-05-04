class DocumentVersionQualityCheckHash
  def initialize(result)
    @result = result
  end

  def call
    {
      valid: result.pass?,
      document_version: document_version_hash,
      summary: summary_hash,
      checks: result.checks.map { check_hash(_1) }
    }
  end

  private

  attr_reader :result

  def document_version
    result.document_version
  end

  def document
    document_version.document
  end

  def document_version_hash
    {
      public_id: document_version.public_id,
      version_label: document_version.version_label,
      status: document_version.status,
      document: {
        public_id: document.public_id,
        title: document.title,
        slug: document.slug,
        visibility_policy: document.visibility_policy
      }
    }
  end

  def summary_hash
    {
      error_count: result.errors.size,
      warning_count: result.warnings.size,
      info_count: result.infos.size
    }
  end

  def check_hash(check)
    {
      key: check.key,
      severity: check.severity,
      message: check.message,
      detail: check.detail
    }
  end
end
