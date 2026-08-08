class EnforceMasterSyncMappingTypes < ActiveRecord::Migration[8.1]
  MAPPING_TYPE_CONSTRAINT = <<~SQL.squish
    (sync_target_type IS NULL AND sync_target_id IS NULL) OR
    (resource_type = 'company' AND sync_target_type = 'Company' AND sync_target_id IS NOT NULL) OR
    (resource_type = 'project' AND sync_target_type = 'Project' AND sync_target_id IS NOT NULL) OR
    (resource_type = 'document' AND sync_target_type = 'Document' AND sync_target_id IS NOT NULL)
  SQL

  RESOURCE_TYPE_CONSTRAINT = "resource_type IN ('company', 'project', 'document')"

  def up
    safety_assured do
      add_check_constraint :external_master_sync_mappings,
        MAPPING_TYPE_CONSTRAINT,
        name: "external_master_sync_mappings_resource_target_type",
        validate: false
      validate_check_constraint :external_master_sync_mappings,
        name: "external_master_sync_mappings_resource_target_type"

      add_check_constraint :master_sync_receipts,
        RESOURCE_TYPE_CONSTRAINT,
        name: "master_sync_receipts_resource_type",
        validate: false
      validate_check_constraint :master_sync_receipts,
        name: "master_sync_receipts_resource_type"
    end
  end

  def down
    remove_check_constraint :master_sync_receipts,
      name: "master_sync_receipts_resource_type"
    remove_check_constraint :external_master_sync_mappings,
      name: "external_master_sync_mappings_resource_target_type"
  end
end
