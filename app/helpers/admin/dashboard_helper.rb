module Admin::DashboardHelper
  def configuration_diagnostic_category_label(check)
    key = check.key.to_s

    case key
    when "SECRET_KEY_BASE", "RAILS_MASTER_KEY", "DOC_IMPORT_TOKEN"
      "秘密値"
    when "ACTIVE_STORAGE_SERVICE", "document_files storage root", /\Astorage\./
      "Storage"
    when "KROKI_ENDPOINT", /\Adocusaurus\./
      "Workspace"
    else
      "環境変数"
    end
  end

  def configuration_diagnostic_status_label(status)
    {
      ok: "OK",
      warning: "警告",
      error: "エラー"
    }.fetch(status.to_sym, status.to_s.upcase)
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
