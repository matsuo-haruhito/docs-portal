require "digest"

module MasterSync
  module AdvisoryLock
    module_function

    def acquire!(key)
      lock_id = Digest::SHA256.digest(key.to_s).unpack1("q>")
      ApplicationRecord.connection.execute("SELECT pg_advisory_xact_lock(#{lock_id})")
    end
  end
end
