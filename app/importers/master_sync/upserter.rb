require "time"

module MasterSync
  class Upserter
    class Unprocessable < StandardError; end
    class MissingDependency < Unprocessable; end

    Result = Data.define(:status, :body)

    SUPPORTED_SOURCE_SYSTEM = "sales-mgt"
    SUPPORTED_OPERATIONS = %w[upsert archive].freeze
    RESOURCE_CLASSES = {
      "company" => Company,
      "project" => Project,
      "document" => Document
    }.freeze

    def initialize(source_system:, resource_type:, external_id:, payload:)
      @source_system = source_system.to_s
      @resource_type = resource_type.to_s
      @external_id = external_id.to_s
      @payload = payload
    end

    def call
      validate_request!
      AdvisoryLock.acquire!("master-sync-mapping:#{source_system}:#{resource_type}:#{external_id}")

      mapping = ExternalMasterSyncMapping.find_by(source_system:, resource_type:, external_id:)
      return stale_result(mapping) if stale?(mapping)

      target = mapping&.sync_target
      validate_target_type!(target)
      target = operation == "archive" ? archive_target(target) : upsert_target(target)

      mapping ||= ExternalMasterSyncMapping.new(source_system:, resource_type:, external_id:)
      mapping.update!(
        sync_target: target,
        source_updated_at:,
        source_attributes: attributes
      )

      Result.new(status: :ok, body: response_body("archive" == operation ? "archived" : "applied", mapping, target))
    rescue ActiveRecord::RecordInvalid => error
      raise Unprocessable, error.record.errors.full_messages.to_sentence
    rescue ActiveRecord::RecordNotUnique
      raise Unprocessable, "同期先で一意制約に競合しました"
    end

    private

    attr_reader :source_system, :resource_type, :external_id, :payload

    def validate_request!
      raise Unprocessable, "source_systemはsales-mgtのみ指定できます" unless source_system == SUPPORTED_SOURCE_SYSTEM
      raise Unprocessable, "resource_typeが未対応です" unless RESOURCE_CLASSES.key?(resource_type)
      raise Unprocessable, "external_idを指定してください" if external_id.blank?
      raise Unprocessable, "external_idは255文字以内で指定してください" if external_id.length > 255
      raise Unprocessable, "リクエスト本文はJSONオブジェクトで指定してください" unless payload.is_a?(Hash)
      raise Unprocessable, "operationはupsertまたはarchiveを指定してください" unless SUPPORTED_OPERATIONS.include?(operation)
      raise Unprocessable, "attributesはJSONオブジェクトで指定してください" unless raw_attributes.is_a?(Hash)

      source_updated_at
    end

    def operation
      @operation ||= payload["operation"].to_s
    end

    def raw_attributes
      payload["attributes"]
    end

    def attributes
      @attributes ||= raw_attributes.deep_stringify_keys
    end

    def source_updated_at
      @source_updated_at ||= Time.iso8601(payload["source_updated_at"].to_s).in_time_zone
    rescue ArgumentError
      raise Unprocessable, "source_updated_atはISO 8601形式で指定してください"
    end

    def stale?(mapping)
      mapping.present? && source_updated_at <= mapping.source_updated_at
    end

    def stale_result(mapping)
      Result.new(status: :ok, body: response_body("stale", mapping, mapping.sync_target))
    end

    def validate_target_type!(target)
      return if target.nil? || target.is_a?(RESOURCE_CLASSES.fetch(resource_type))

      raise Unprocessable, "外部mappingの同期先種別が一致していません"
    end

    def upsert_target(target)
      case resource_type
      when "company" then upsert_company(target || Company.new)
      when "project" then upsert_project(target || Project.new)
      when "document" then upsert_document(target || Document.new)
      end
    end

    def upsert_company(company)
      supplied_domain = attributes["domain"].to_s.strip.presence
      company.domain = supplied_domain || fallback_domain if company.new_record? || supplied_domain.present?
      company.name = attributes["name"]
      company.active = boolean_attribute("active", default: true)
      company.save!
      company
    end

    def upsert_project(project)
      project.code = required_attribute("code", fallback: "project_number")
      project.name = required_attribute("name")
      project.description = attributes["description"].presence || attributes["notes"]
      project.company = resolve_mapping_target("company", attributes["company_external_id"], required: false)
      project.active = boolean_attribute("active", default: true)
      project.save!
      project
    end

    def upsert_document(document)
      document.project = resolve_mapping_target("project", attributes["project_external_id"], required: true)
      document.title = required_attribute("title", fallback: "file_name")
      document.slug = required_attribute("slug")
      document.source_authority = :sales_mgt
      document.archived_at = nil
      document.archived_by_user = nil
      document.save!
      document
    end

    def archive_target(target)
      return nil unless target

      case target
      when Company, Project
        target.update!(active: false)
      when Document
        target.update!(archived_at: Time.current, archived_by_user: nil)
      end
      target
    end

    def resolve_mapping_target(expected_resource_type, referenced_external_id, required:)
      if referenced_external_id.blank?
        raise Unprocessable, "#{expected_resource_type}_external_idを指定してください" if required

        return nil
      end

      mapping = ExternalMasterSyncMapping.find_by(
        source_system:,
        resource_type: expected_resource_type,
        external_id: referenced_external_id.to_s
      )
      expected_class = RESOURCE_CLASSES.fetch(expected_resource_type)
      target = mapping&.sync_target
      return target if target.is_a?(expected_class)

      raise MissingDependency, "#{expected_resource_type}_external_idに対応する同期先が見つかりません"
    end

    def required_attribute(key, fallback: nil)
      value = attributes[key].presence
      value ||= attributes[fallback].presence if fallback
      return value if value

      raise Unprocessable, "#{key}を指定してください"
    end

    def boolean_attribute(key, default:)
      return default unless attributes.key?(key)

      value = attributes[key]
      return value if value.equal?(true) || value.equal?(false)

      raise Unprocessable, "#{key}はtrueまたはfalseで指定してください"
    end

    def fallback_domain
      normalized = external_id.downcase.gsub(/[^a-z0-9-]+/, "-").gsub(/\A-+|-+\z/, "")
      normalized = Digest::SHA256.hexdigest(external_id).first(16) if normalized.blank?
      "sales-mgt-#{normalized}.invalid"
    end

    def response_body(status, mapping, target)
      {
        status:,
        mapping_id: mapping.public_id,
        source_system:,
        resource_type:,
        external_id:,
        source_updated_at: mapping.source_updated_at.iso8601(6),
        portal_public_id: target&.public_id,
        portal_url: portal_url(target)
      }
    end

    def portal_url(target)
      routes = Rails.application.routes.url_helpers

      case target
      when Company
        routes.edit_admin_company_path(target.public_id)
      when Project
        routes.project_path(target.code)
      when Document
        routes.project_document_path(target.project.code, target.slug)
      end
    end
  end
end
