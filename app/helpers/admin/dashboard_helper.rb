module Admin::DashboardHelper
  CONFIGURATION_DIAGNOSTIC_CATEGORY_LABELS = {
    secret: "秘密値",
    storage: "Storage",
    workspace: "Workspace",
    environment: "環境変数"
  }.freeze

  CONFIGURATION_DIAGNOSTIC_STATUS_LABELS = {
    ok: "OK",
    warning: "警告",
    error: "エラー"
  }.freeze

  def configuration_diagnostic_category_key(check)
    key = check.key.to_s

    case key
    when "SECRET_KEY_BASE", "RAILS_MASTER_KEY", "DOC_IMPORT_TOKEN"
      :secret
    when "ACTIVE_STORAGE_SERVICE", "document_files storage root", /\Astorage\./
      :storage
    when "KROKI_ENDPOINT", /\Adocusaurus\./
      :workspace
    else
      :environment
    end
  end

  def configuration_diagnostic_category_label(check)
    configuration_diagnostic_category_filter_label(configuration_diagnostic_category_key(check))
  end

  def configuration_diagnostic_category_filter_options
    CONFIGURATION_DIAGNOSTIC_CATEGORY_LABELS.map { |key, label| [label, key.to_s] }
  end

  def configuration_diagnostic_category_filter_label(value)
    CONFIGURATION_DIAGNOSTIC_CATEGORY_LABELS.fetch(value.to_sym, value.to_s)
  end

  def configuration_diagnostic_status_label(status)
    configuration_diagnostic_status_filter_label(status)
  end

  def configuration_diagnostic_status_filter_options
    CONFIGURATION_DIAGNOSTIC_STATUS_LABELS.map { |key, label| [label, key.to_s] }
  end

  def configuration_diagnostic_status_filter_label(status)
    CONFIGURATION_DIAGNOSTIC_STATUS_LABELS.fetch(status.to_sym, status.to_s.upcase)
  end

  def configuration_diagnostic_status_badge_class(status)
    base_class = "inline-flex rounded px-2 py-1 text-xs font-semibold"

    status_class = case status.to_sym
                   when :ok
                     "bg-green-100 text-green-800"
                   when :warning
                     "bg-yellow-100 text-yellow-800"
                   when :error
                     "bg-red-100 text-red-800"
                   else
                     "bg-gray-100 text-gray-700"
                   end

    "#{base_class} #{status_class}"
  end
end
