# Configure Active Record Encryption from environment variables when needed.
#
# The actual key values must be provided at deploy/runtime and should never be
# committed to the repository. This allows encrypted attributes such as
# ExternalFolderSyncSource#auth_config to work in Docker-style environments that
# rely on .env instead of Rails credentials.
Rails.application.config.active_record.encryption.tap do |encryption_config|
  primary_key = ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence
  deterministic_key = ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence
  key_derivation_salt = ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence

  encryption_config.primary_key = primary_key if primary_key
  encryption_config.deterministic_key = deterministic_key if deterministic_key
  encryption_config.key_derivation_salt = key_derivation_salt if key_derivation_salt
end
