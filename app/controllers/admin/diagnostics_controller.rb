class Admin::DiagnosticsController < Admin::BaseController
  include Admin::OperationalFailureReporting

  CONFIGURATION_STATUS_FILTERS = %w[ok warning error].freeze
  CONFIGURATION_CATEGORY_FILTERS = %w[secret storage workspace environment].freeze

  before_action :require_admin_only!

  def index
    @configuration_diagnostic = ApplicationConfigurationDiagnostic.new.call
    prepare_configuration_diagnostic_filters
    @document_file_health = DocumentFileHealthCheck.new.call
    @storage_usage_summary = StorageUsageSummary.new.call
    @model_browser_entries = Admin::ModelBrowserCatalog.entries
    @model_browser_entry_summaries = @model_browser_entries.index_with { Admin::ModelBrowserSummary.for(_1) }
    @generated_file_run_failure_alert_candidates = generated_file_run_failure_alert_candidates
    @generated_file_run_failure_alert_digest_markdown = generated_file_run_failure_alert_digest_markdown
    @document_delivery_failure_alert_candidates = document_delivery_failure_alert_candidates
    @external_sync_failure_alert_candidates = external_sync_failure_alert_candidates
    @external_sync_failure_alert_digest_markdown = external_sync_failure_alert_digest_markdown
    @operational_failure_summary = operational_failure_summary
  end

  private

  def prepare_configuration_diagnostic_filters
    @configuration_status_filter = normalize_configuration_filter(params[:configuration_status], CONFIGURATION_STATUS_FILTERS)
    @configuration_category_filter = normalize_configuration_filter(params[:configuration_category], CONFIGURATION_CATEGORY_FILTERS)

    checks = @configuration_diagnostic.checks
    checks = checks.select { |check| check.status.to_s == @configuration_status_filter } if @configuration_status_filter.present?
    if @configuration_category_filter.present?
      checks = checks.select { |check| helpers.configuration_diagnostic_category_key(check).to_s == @configuration_category_filter }
    end

    @configuration_diagnostic_checks = checks
    @configuration_diagnostic_filter_count = checks.size
    @configuration_diagnostic_total_count = @configuration_diagnostic.checks.size
    @configuration_diagnostic_filters_active = @configuration_status_filter.present? || @configuration_category_filter.present?
  end

  def normalize_configuration_filter(value, allowed_values)
    normalized_value = value.to_s.presence
    return unless allowed_values.include?(normalized_value)

    normalized_value
  end

  def generated_file_run_failure_alert_digest_markdown
    entries = GeneratedFiles::RunFailureAlertHandoff.new(
      candidates: @generated_file_run_failure_alert_candidates
    ).call

    GeneratedFiles::RunFailureAlertHandoff.markdown(entries)
  end

  def external_sync_failure_alert_digest_markdown
    entries = ExternalFolderSyncRuns::FailureAlertHandoff.new(
      candidates: @external_sync_failure_alert_candidates
    ).call

    ExternalFolderSyncRuns::FailureAlertHandoff.markdown(entries)
  end
end
