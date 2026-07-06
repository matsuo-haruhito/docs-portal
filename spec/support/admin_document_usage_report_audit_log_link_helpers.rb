module AdminDocumentUsageReportAuditLogLinkHelpers
  def audit_log_link(slug)
    parsed_html.css("a").find do |link|
      href = link["href"].to_s

      link.text.squish == "監査ログへ" &&
        href.start_with?(admin_access_logs_path) &&
        href.include?("project_id=#{project.id}") &&
        href.include?("document_q=#{slug}")
    end
  end

  def summary_audit_log_link
    parsed_html.css("a").find do |link|
      href = link["href"].to_s

      link.text.squish == "案件の監査ログへ" &&
        href.start_with?(admin_access_logs_path) &&
        href.include?("project_id=#{project.id}")
    end
  end
end

RSpec.configure do |config|
  config.prepend AdminDocumentUsageReportAuditLogLinkHelpers, type: :request
end
