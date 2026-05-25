module Admin::ZipImportsHelper
  def import_dry_run_status_label(dry_run_or_value)
    value = dry_run_or_value.respond_to?(:status) ? dry_run_or_value.status : dry_run_or_value
    localized_label("import_dry_runs.status", value)
  end

  def import_dry_run_tree_change_type_label(change_type)
    localized_label("import_dry_run_tree_preview.change_type", change_type)
  end
end
