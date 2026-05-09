require "bcrypt"
require "csv"
require "digest"

module SeedSupport
  class MasterDataImporter
    DATA_DIR = Rails.root.join("db", "seeds", "data")

    def run
      ActiveRecord::Base.transaction do
        seed_companies
        seed_users
        seed_projects
        seed_project_memberships
        seed_documents
        seed_document_versions
        seed_latest_document_versions
        seed_document_files
        seed_document_permissions
        seed_access_logs
      end

      reset_sequences
    end

    private

    def seed_companies
      existing = Company.all.index_by(&:domain)
      upsert_rows!(
        Company,
        rows("companies.csv").map do |row|
          company = existing[row.fetch("domain")]
          {
            public_id: public_id_for(company, "com", row.fetch("domain")),
            domain: row.fetch("domain"),
            name: row["name"].presence,
            active: bool_value(row["active"])
          }.merge(timestamps(company))
        end,
        unique_by: :index_companies_on_domain
      )
    end

    def seed_users
      companies = Company.all.index_by(&:domain)
      existing = User.all.index_by(&:email_address)
      upsert_rows!(
        User,
        rows("users.csv").map do |row|
          user = existing[row.fetch("email_address")]
          {
            public_id: public_id_for(user, "usr", row.fetch("email_address")),
            email_address: row.fetch("email_address"),
            name: row["name"].presence,
            user_type: User.user_types.fetch(row.fetch("user_type")),
            company_id: companies.fetch(row.fetch("company_domain")).id,
            password_digest: BCrypt::Password.create(row.fetch("password")),
            active: bool_value(row["active"])
          }.merge(timestamps(user))
        end,
        unique_by: :index_users_on_email_address
      )
    end

    def seed_projects
      existing = Project.all.index_by(&:code)
      upsert_rows!(
        Project,
        rows("projects.csv").map do |row|
          project = existing[row.fetch("code")]
          {
            public_id: public_id_for(project, "prj", row.fetch("code")),
            code: row.fetch("code"),
            name: row.fetch("name"),
            description: row["description"],
            active: bool_value(row["active"])
          }.merge(timestamps(project))
        end,
        unique_by: :index_projects_on_code
      )
    end

    def seed_project_memberships
      projects = Project.all.index_by(&:code)
      users = User.all.index_by(&:email_address)
      existing = ProjectMembership.all.index_by { composite_key(_1.project_id, _1.user_id) }

      upsert_rows!(
        ProjectMembership,
        rows("project_memberships.csv").map do |row|
          project_id = projects.fetch(row.fetch("project_code")).id
          user_id = users.fetch(row.fetch("user_email")).id
          membership = existing[composite_key(project_id, user_id)]
          {
            public_id: public_id_for(membership, "pmem", row.fetch("project_code"), row.fetch("user_email")),
            project_id:,
            user_id:,
            role: ProjectMembership.roles.fetch(row.fetch("role"))
          }.merge(timestamps(membership))
        end,
        unique_by: :index_project_memberships_on_project_id_and_user_id
      )
    end

    def seed_documents
      projects = Project.all.index_by(&:code)
      existing = Document.all.index_by { composite_key(_1.project_id, _1.slug) }

      upsert_rows!(
        Document,
        document_rows.map do |row|
          project_id = projects.fetch(row.fetch("project_code")).id
          document = existing[composite_key(project_id, row.fetch("slug"))]
          {
            public_id: public_id_for(document, "doc", row.fetch("project_code"), row.fetch("slug")),
            project_id:,
            title: row.fetch("title"),
            slug: row.fetch("slug"),
            category: Document.categories.fetch(row.fetch("category")),
            document_kind: Document.document_kinds.fetch(row.fetch("document_kind")),
            visibility_policy: Document.visibility_policies.fetch(row.fetch("visibility_policy"))
          }.merge(timestamps(document))
        end,
        unique_by: :index_documents_on_project_id_and_slug
      )
    end

    def seed_document_versions
      users = User.all.index_by(&:email_address)
      documents = documents_by_project_and_slug
      existing = DocumentVersion.all.index_by { composite_key(_1.document_id, _1.version_label) }

      upsert_rows!(
        DocumentVersion,
        rows("document_versions.csv").map do |row|
          project_code = project_code_by_document_slug.fetch(row.fetch("document_slug"))
          document_id = documents.fetch(composite_key(project_code, row.fetch("document_slug"))).id
          version = existing[composite_key(document_id, row.fetch("version_label"))]
          {
            public_id: public_id_for(version, "ver", project_code, row.fetch("document_slug"), row.fetch("version_label")),
            document_id:,
            version_label: row.fetch("version_label"),
            status: DocumentVersion.statuses.fetch(row.fetch("status")),
            source_commit_hash: row.fetch("source_commit_hash"),
            changelog_summary: row["changelog_summary"],
            published_at: parse_time(row["published_at"]),
            published_by_user_id: row["published_by_email"].present? ? users.fetch(row["published_by_email"]).id : nil,
            markdown_entry_path: row["markdown_entry_path"].presence,
            site_build_path: row["site_build_path"].presence,
            pdf_snapshot_path: row["pdf_snapshot_path"].presence
          }.merge(timestamps(version))
        end,
        unique_by: :index_document_versions_on_document_id_and_version_label
      )
    end

    def seed_latest_document_versions
      documents = documents_by_project_and_slug
      versions = versions_by_project_slug_and_label
      upsert_rows!(
        Document,
        document_rows.filter_map do |row|
          next if row["latest_version_label"].blank?

          document = documents.fetch(composite_key(row.fetch("project_code"), row.fetch("slug")))
          latest_version = versions.fetch(composite_key(row.fetch("project_code"), row.fetch("slug"), row.fetch("latest_version_label")))
          {
            id: document.id,
            public_id: document.public_id,
            project_id: document.project_id,
            title: document.title,
            slug: document.slug,
            category: document.category_before_type_cast,
            document_kind: document.document_kind_before_type_cast,
            visibility_policy: document.visibility_policy_before_type_cast,
            latest_version_id: latest_version.id
          }.merge(timestamps(document))
        end,
        unique_by: :id
      )
    end

    def seed_document_files
      versions = versions_by_project_slug_and_label
      existing = DocumentFile.all.index_by(&:storage_key)
      upsert_rows!(
        DocumentFile,
        rows("document_files.csv").map do |row|
          project_code = project_code_by_document_slug.fetch(row.fetch("document_slug"))
          version = versions.fetch(composite_key(project_code, row.fetch("document_slug"), row.fetch("version_label")))
          file = existing[row.fetch("storage_key")]
          {
            public_id: public_id_for(file, "file", row.fetch("storage_key")),
            document_version_id: version.id,
            file_name: row.fetch("file_name"),
            content_type: row.fetch("content_type"),
            storage_key: row.fetch("storage_key"),
            file_size: row.fetch("file_size").to_i,
            sort_order: row.fetch("sort_order").to_i
          }.merge(timestamps(file))
        end,
        unique_by: :index_document_files_on_storage_key
      )
    end

    def seed_document_permissions
      companies = Company.all.index_by(&:domain)
      users = User.all.index_by(&:email_address)
      documents = documents_by_project_and_slug
      existing = DocumentPermission.all.index_by { composite_key(_1.document_id, _1.company_id, _1.user_id) }
      permission_rows = rows("document_permissions.csv")
      keys = permission_rows.map do |row|
        project_code = project_code_by_document_slug.fetch(row.fetch("document_slug"))
        document_id = documents.fetch(composite_key(project_code, row.fetch("document_slug"))).id
        company_id = row["company_domain"].present? ? companies.fetch(row["company_domain"]).id : nil
        user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil
        composite_key(document_id, company_id, user_id)
      end
      ids = next_seed_ids(existing, keys)

      upsert_rows!(
        DocumentPermission,
        permission_rows.each_with_index.map do |row, index|
          project_code = project_code_by_document_slug.fetch(row.fetch("document_slug"))
          document_id = documents.fetch(composite_key(project_code, row.fetch("document_slug"))).id
          company_id = row["company_domain"].present? ? companies.fetch(row["company_domain"]).id : nil
          user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil
          permission = existing[composite_key(document_id, company_id, user_id)]
          {
            id: ids[index],
            public_id: public_id_for(permission, "perm", project_code, row.fetch("document_slug"), row["company_domain"], row["user_email"]),
            document_id:,
            company_id:,
            user_id:,
            access_level: DocumentPermission.access_levels.fetch(row.fetch("access_level"))
          }.merge(timestamps(permission))
        end,
        unique_by: :id
      )
    end

    def seed_access_logs
      companies = Company.all.index_by(&:domain)
      users = User.all.index_by(&:email_address)
      projects = Project.all.index_by(&:code)
      documents = documents_by_project_and_slug
      versions = versions_by_project_slug_and_label
      existing = AccessLog.all.index_by do |log|
        composite_key(log.project_id, log.document_id, log.document_version_id, log.user_id, log.company_id, log.action_type_before_type_cast, log.target_type, log.target_name, log.ip_address, log.user_agent, log.accessed_at)
      end
      log_rows = rows("access_logs.csv")
      keys = log_rows.map { access_log_key(_1, companies:, users:, projects:, documents:, versions:) }
      ids = next_seed_ids(existing, keys)

      upsert_rows!(
        AccessLog,
        log_rows.each_with_index.map do |row, index|
          project_code = row.fetch("project_code")
          document = documents.fetch(composite_key(project_code, row.fetch("document_slug")))
          version = versions.fetch(composite_key(project_code, row.fetch("document_slug"), row.fetch("version_label")))
          user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil
          company_id = row["company_domain"].present? ? companies.fetch(row["company_domain"]).id : nil
          action_type = AccessLog.action_types.fetch(row.fetch("action_type"))
          accessed_at = parse_time(row.fetch("accessed_at"))
          log = existing[access_log_key(row, companies:, users:, projects:, documents:, versions:)]
          {
            id: ids[index],
            public_id: public_id_for(log, "alog", project_code, row.fetch("document_slug"), row.fetch("version_label"), row["user_email"], row["company_domain"], row.fetch("action_type"), row.fetch("target_type"), row["target_name"], row["ip_address"], row["user_agent"], row.fetch("accessed_at")),
            project_id: projects.fetch(project_code).id,
            document_id: document.id,
            document_version_id: version.id,
            user_id:,
            company_id:,
            action_type:,
            target_type: row.fetch("target_type"),
            target_name: row["target_name"],
            ip_address: row["ip_address"],
            user_agent: row["user_agent"],
            accessed_at:
          }.merge(timestamps(log))
        end,
        unique_by: :id
      )
    end

    def access_log_key(row, companies:, users:, projects:, documents:, versions:)
      project_code = row.fetch("project_code")
      document = documents.fetch(composite_key(project_code, row.fetch("document_slug")))
      version = versions.fetch(composite_key(project_code, row.fetch("document_slug"), row.fetch("version_label")))
      user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil
      company_id = row["company_domain"].present? ? companies.fetch(row["company_domain"]).id : nil
      composite_key(projects.fetch(project_code).id, document.id, version.id, user_id, company_id, AccessLog.action_types.fetch(row.fetch("action_type")), row.fetch("target_type"), row["target_name"], row["ip_address"], row["user_agent"], parse_time(row.fetch("accessed_at")))
    end

    def document_rows
      @document_rows ||= rows("documents.csv")
    end

    def project_code_by_document_slug
      @project_code_by_document_slug ||= document_rows.each_with_object({}) { |row, result| result[row.fetch("slug")] = row.fetch("project_code") }
    end

    def documents_by_project_and_slug
      Document.includes(:project).index_by { composite_key(_1.project.code, _1.slug) }
    end

    def versions_by_project_slug_and_label
      DocumentVersion.includes(document: :project).index_by { composite_key(_1.document.project.code, _1.document.slug, _1.version_label) }
    end

    def rows(name)
      CSV.read(DATA_DIR.join(name), headers: true, encoding: "UTF-8")
    end

    def bool_value(value)
      value.to_s != "false"
    end

    def parse_time(value)
      value.present? ? Time.zone.parse(value) : nil
    end

    def timestamps(record)
      now = Time.current
      { created_at: record&.created_at || now, updated_at: now }
    end

    def composite_key(*parts)
      parts
    end

    def seed_public_id(prefix, *parts)
      raw_key = parts.flatten.map { _1.to_s.presence || "-" }.join(":")
      "#{prefix}_#{Digest::SHA256.hexdigest(raw_key)[0, 20]}"
    end

    def public_id_for(record, prefix, *parts)
      record&.public_id || seed_public_id(prefix, *parts)
    end

    def next_seed_ids(existing_map, rows)
      next_id = existing_map.values.map(&:id).compact.max.to_i
      rows.map do |key|
        existing = existing_map[key]
        if existing
          existing.id
        else
          next_id += 1
        end
      end
    end

    def upsert_rows!(model, rows, unique_by:)
      return if rows.empty?

      model.upsert_all(rows, unique_by:)
    end

    def reset_sequences
      %w[access_logs document_permissions].each do |table_name|
        ActiveRecord::Base.connection.reset_pk_sequence!(table_name)
      end
    end
  end
end
