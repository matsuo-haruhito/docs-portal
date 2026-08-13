class Admin::DashboardController < Admin::BaseController
  include Admin::OperationalFailureReporting

  OPERATIONAL_FAILURE_STALE_THRESHOLD = Admin::OperationalFailureReporting::OPERATIONAL_FAILURE_STALE_THRESHOLD
  GENERATED_FILE_ALERT_CANDIDATE_LIMIT = Admin::OperationalFailureReporting::ALERT_CANDIDATE_LIMIT
  GENERATED_FILE_ALERT_CANDIDATE_LOOKBACK_LIMIT = Admin::OperationalFailureReporting::ALERT_CANDIDATE_LOOKBACK_LIMIT
  DOCUMENT_DELIVERY_ALERT_CANDIDATE_LIMIT = Admin::OperationalFailureReporting::ALERT_CANDIDATE_LIMIT
  DOCUMENT_DELIVERY_ALERT_CANDIDATE_LOOKBACK_LIMIT = Admin::OperationalFailureReporting::ALERT_CANDIDATE_LOOKBACK_LIMIT
  EXTERNAL_SYNC_ALERT_CANDIDATE_LIMIT = Admin::OperationalFailureReporting::ALERT_CANDIDATE_LIMIT
  EXTERNAL_SYNC_ALERT_CANDIDATE_LOOKBACK_LIMIT = Admin::OperationalFailureReporting::ALERT_CANDIDATE_LOOKBACK_LIMIT
  MAIN_MODEL_KEYS = %w[companies users projects documents].freeze
  RECENT_OPERATIONAL_ISSUE_LIMIT = 5

  before_action :require_internal_admin_for_dashboard!, only: :index

  def index
    if current_user&.company_master_admin?
      render :company_master_admin
      return
    end

    @configuration_diagnostic = ApplicationConfigurationDiagnostic.new.call
    @document_file_health = DocumentFileHealthCheck.new.call
    @model_browser_entries = MAIN_MODEL_KEYS.map { Admin::ModelBrowserCatalog.fetch!(_1) }
    @model_browser_entry_summaries = @model_browser_entries.index_with { Admin::ModelBrowserSummary.for(_1) }
    @generated_file_run_failure_alert_candidates = generated_file_run_failure_alert_candidates
    @document_delivery_failure_alert_candidates = document_delivery_failure_alert_candidates
    @external_sync_failure_alert_candidates = external_sync_failure_alert_candidates
    @continuing_failure_count = [
      @generated_file_run_failure_alert_candidates,
      @document_delivery_failure_alert_candidates,
      @external_sync_failure_alert_candidates
    ].sum(&:size)
    @recent_operational_issues = operational_failure_summary
      .select { _1[:count].positive? }
      .sort_by { _1[:latest_at] || Time.zone.at(0) }
      .reverse
      .first(RECENT_OPERATIONAL_ISSUE_LIMIT)
  end

  private

  def require_internal_admin_for_dashboard!
    return if current_user&.company_master_admin?

    require_admin_only!
  end
end
