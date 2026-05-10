class AddDryRunPolicyToGitImportSources < ActiveRecord::Migration[8.1]
  def change
    add_column :git_import_sources, :dry_run_policy, :integer, null: false, default: 1
  end
end
