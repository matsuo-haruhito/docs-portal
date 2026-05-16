require "fileutils"
require "set"

module ExternalFolderSync
  class Runner
    class Error < StandardError; end

    def initialize(source:, mode:, actor:)
      @source = source
      @mode = mode.to_s
      @actor = actor
      @entries_by_id = {}
    end

    def call
      ensure_supported!
      run = source.external_folder_sync_runs.create!(
        mode:,
        status: :running,
        started_at: Time.current
      )

      entries = client.list_files
      @entries_by_id = entries.index_by(&:id)
      result = entries.map { plan_entry(_1) }
      result.each { apply_entry(_1) } if apply?
      append_missing_items!(entries, result)
      finish_success!(run, result)
    rescue => e
      finish_failure!(run, e) if defined?(run) && run
      source.update!(last_error_message: e.message)
      raise
    end

    private

    attr_reader :source, :mode, :actor, :entries_by_id

    def client
      @client ||= ExternalFolderSync::GoogleDriveClient.new(source:)
    end

    def ensure_supported!
      raise Error, "Only Google Drive sync is supported" unless source.google_drive?
      raise Error, "Only external_to_portal sync is supported" unless source.external_to_portal?
      raise Error, "Sync source is disabled" unless source.enabled?
    end

    def apply?
      mode == "apply"
    end

    def plan_entry(entry)
      item = source.external_folder_sync_items.find_by(external_item_id: entry.id)
      change_reasons = change_reasons_for(item, entry)
      action = if entry.exportable && entry.export_mime_type.blank?
        "error"
      elsif item.blank?
        "create"
      elsif change_reasons.any?
        "update"
      else
        "skip"
      end

      {
        "action" => action,
        "attention_level" => attention_level_for(action, change_reasons),
        "change_reasons" => change_reasons,
        "external_item_id" => entry.id,
        "path" => entry.download_path,
        "source_path" => entry.path,
        "previous_path" => item&.path,
        "name" => entry.download_name,
        "source_name" => entry.name,
        "previous_name" => item&.name,
        "mime_type" => entry.download_mime_type,
        "source_mime_type" => entry.mime_type,
        "previous_mime_type" => item&.mime_type,
        "size" => entry.size,
        "previous_size" => item&.size,
        "checksum" => entry.checksum,
        "previous_checksum" => item&.checksum,
        "external_modified_at" => entry.modified_at&.iso8601,
        "previous_external_modified_at" => item&.external_modified_at&.iso8601,
        "web_view_link" => entry.web_view_link,
        "exported" => entry.exportable,
        "export_mime_type" => entry.export_mime_type,
        "message" => message_for(action, entry, change_reasons)
      }
    end

    def changed?(item, entry)
      change_reasons_for(item, entry).any?
    end

    def change_reasons_for(item, entry)
      return ["新規ファイル"] if item.blank?

      reasons = []
      reasons << "ファイル内容またはリビジョンが変更されています" if item.checksum.to_s != entry.checksum.to_s
      reasons << "外部側の更新日時が変わっています" if item.external_modified_at.to_i != entry.modified_at.to_i
      reasons << "同期後の保存パスが変わっています" if item.path != entry.download_path
      reasons << "ファイル名が変わっています" if item.name != entry.download_name
      reasons << "MIMEタイプが変わっています" if item.mime_type != entry.download_mime_type
      reasons << "ファイルサイズが変わっています" if item.size.present? && entry.size.present? && item.size.to_i != entry.size.to_i
      reasons
    end

    def attention_level_for(action, change_reasons)
      return "danger" if action == "error" || action == "delete_detected"
      return "warning" if change_reasons.any? { _1.include?("パス") || _1.include?("MIME") }
      return "info" if action == "create" || action == "update"
      "none"
    end

    def message_for(action, entry, change_reasons)
      return "Google native file export is not supported for this mime type" if action == "error" && entry.exportable
      return "New file" if action == "create"
      return change_reasons.join(" / ") if action == "update" && change_reasons.any?
      return "External file changed" if action == "update"
      "Unchanged"
    end

    def apply_entry(plan)
      return if plan.fetch("action") == "skip"
      return record_error_item!(plan) if plan.fetch("action") == "error"

      ActiveRecord::Base.transaction do
        document = find_or_create_document!(plan)
        version = create_document_version!(document, plan)
        file = create_document_file!(version, plan)
        upsert_item!(plan, document, version, file)
      end
    rescue => e
      plan["action"] = "error"
      plan["attention_level"] = "danger"
      plan["message"] = e.message
      record_error_item!(plan)
    end

    def find_or_create_document!(plan)
      existing = source.external_folder_sync_items.find_by(external_item_id: plan.fetch("external_item_id"))&.document
      return existing if existing.present?

      title = File.basename(plan.fetch("name"), ".*").presence || plan.fetch("name")
      source.project.documents.create!(
        title:,
        slug: unique_slug(title),
        category: :other,
        document_kind: document_kind_for(plan.fetch("mime_type")),
        visibility_policy: :internal_only,
        importance_level: :reference
      )
    end

    def create_document_version!(document, plan)
      label = Time.current.strftime("drive-%Y%m%d%H%M%S")
      version = document.document_versions.create!(
        version_label: unique_version_label(document, label),
        source_commit_hash: "google-drive:#{plan.fetch("external_item_id")}",
        status: :published,
        published_at: Time.current,
        published_by_user: actor,
        snapshot_kind: "attachment"
      )
      version.assign_source_path_metadata!(source_path: plan.fetch("path"), snapshot_kind: "attachment")
      version.save!
      version
    end

    def create_document_file!(version, plan)
      entry = entries_by_id.fetch(plan.fetch("external_item_id"))
      content = client.download_entry(entry)
      storage_key = storage_key_for(version, plan.fetch("name"))
      path = DocumentFile.storage_root.join(storage_key)
      FileUtils.mkdir_p(path.dirname)
      File.binwrite(path, content)

      file = version.document_files.create!(
        file_name: plan.fetch("name"),
        content_type: plan.fetch("mime_type").presence || "application/octet-stream",
        file_size: content.bytesize,
        storage_key:,
        scan_status: :scan_pending,
        sort_order: 0
      )
      file.assign_search_text_from_path!(plan.fetch("path"))
      file.save!
      file
    end

    def upsert_item!(plan, document, version, file)
      item = source.external_folder_sync_items.find_or_initialize_by(external_item_id: plan.fetch("external_item_id"))
      item.assign_attributes(
        document:,
        document_version: version,
        document_file: file,
        external_parent_id: nil,
        path: plan.fetch("path"),
        name: plan.fetch("name"),
        mime_type: plan.fetch("mime_type"),
        size: file.file_size,
        checksum: plan["checksum"],
        external_modified_at: parse_time(plan["external_modified_at"]),
        portal_modified_at: Time.current,
        sync_status: :synced,
        last_error_message: nil,
        provider_metadata: provider_metadata_for(plan)
      )
      item.save!
    end

    def record_error_item!(plan)
      item = source.external_folder_sync_items.find_or_initialize_by(external_item_id: plan.fetch("external_item_id"))
      item.assign_attributes(
        path: plan.fetch("path"),
        name: plan.fetch("name"),
        mime_type: plan.fetch("mime_type"),
        size: plan.fetch("size"),
        checksum: plan["checksum"],
        external_modified_at: parse_time(plan["external_modified_at"]),
        sync_status: :error,
        last_error_message: plan["message"],
        provider_metadata: provider_metadata_for(plan)
      )
      item.save!
    end

    def append_missing_items!(entries, result)
      seen_ids = entries.map(&:id).to_set
      source.external_folder_sync_items.where.not(external_item_id: seen_ids).find_each do |item|
        item.update!(sync_status: :delete_detected) if apply?
        result << {
          "action" => "delete_detected",
          "attention_level" => "danger",
          "change_reasons" => ["外部フォルダの一覧に存在しません"],
          "external_item_id" => item.external_item_id,
          "path" => item.path,
          "name" => item.name,
          "previous_path" => item.path,
          "previous_name" => item.name,
          "previous_mime_type" => item.mime_type,
          "previous_size" => item.size,
          "previous_checksum" => item.checksum,
          "previous_external_modified_at" => item.external_modified_at&.iso8601,
          "message" => "External file is no longer listed; portal content was kept"
        }
      end
    end

    def finish_success!(run, result)
      summary = summary_for(result)
      run.update!(
        status: summary.fetch("errors_count").positive? ? :partial : :completed,
        finished_at: Time.current,
        items_scanned_count: result.size,
        items_created_count: summary.fetch("created_count"),
        items_updated_count: summary.fetch("updated_count"),
        items_skipped_count: summary.fetch("skipped_count"),
        items_deleted_count: summary.fetch("deleted_count"),
        errors_count: summary.fetch("errors_count"),
        summary_json: summary,
        result_json: result
      )
      source.update!(last_synced_at: Time.current, last_error_message: nil, cursor: safe_start_page_token) if apply?
      run
    end

    def safe_start_page_token
      client.start_page_token
    rescue ExternalFolderSync::GoogleDriveClient::Error
      source.cursor
    end

    def finish_failure!(run, error)
      run.update!(
        status: :failed,
        finished_at: Time.current,
        error_message: error.message
      )
    end

    def summary_for(result)
      {
        "created_count" => result.count { _1["action"] == "create" },
        "updated_count" => result.count { _1["action"] == "update" },
        "skipped_count" => result.count { _1["action"] == "skip" },
        "deleted_count" => result.count { _1["action"] == "delete_detected" },
        "errors_count" => result.count { _1["action"] == "error" },
        "needs_attention_count" => result.count { _1["attention_level"].in?(%w[warning danger]) }
      }
    end

    def provider_metadata_for(plan)
      {
        web_view_link: plan["web_view_link"],
        source_path: plan["source_path"],
        source_name: plan["source_name"],
        source_mime_type: plan["source_mime_type"],
        exported: plan["exported"],
        export_mime_type: plan["export_mime_type"],
        last_change_reasons: plan["change_reasons"],
        last_attention_level: plan["attention_level"]
      }
    end

    def unique_slug(title)
      base = title.to_s.parameterize.presence || "google-drive-file"
      candidate = base
      index = 2
      while source.project.documents.exists?(slug: candidate)
        candidate = "#{base}-#{index}"
        index += 1
      end
      candidate
    end

    def unique_version_label(document, label)
      candidate = label
      index = 2
      while document.document_versions.exists?(version_label: candidate)
        candidate = "#{label}-#{index}"
        index += 1
      end
      candidate
    end

    def storage_key_for(version, file_name)
      safe_name = file_name.to_s.tr("\\/", "_").presence || "google-drive-file"
      "external_folder_syncs/#{source.id}/#{version.id}/#{SecureRandom.uuid}-#{safe_name}"
    end

    def document_kind_for(mime_type)
      case mime_type.to_s
      when "application/pdf" then :pdf
      when /spreadsheet|excel/ then :excel
      when /word/ then :word
      else :mixed
      end
    end

    def parse_time(value)
      Time.zone.parse(value) if value.present?
    end
  end
end
