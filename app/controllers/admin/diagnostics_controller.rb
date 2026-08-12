# frozen_string_literal: true

class Admin::DiagnosticsController < Admin::BaseController
  before_action :require_admin_only!

  def index
    @configuration_checks = ApplicationConfiguration::EnvironmentChecks.all
    @storage_summary = Admin::StorageUsageSummary.new
  end
end
