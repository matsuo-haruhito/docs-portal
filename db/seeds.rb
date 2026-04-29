require "bcrypt"
require "csv"
require "digest"
require "rack/mime"
require_relative "seeds/support/docusaurus_builder"

puts "Seeding from CSV..."

SEED_DATA_DIR = Rails.root.join("db", "seeds", "data")
EXTERNAL_SAMPLE_ROOT = Rails.root.join("storage", "document_files", "external_samples")

def csv_rows(name)
  CSV.read(SEED_DATA_DIR.join(name), headers: true, encoding: "UTF-8")
end

def bool_value(value)
  value.to_s != "false"
end

def parse_time(value)
  value.present? ? Time.zone.parse(value) : nil
end

def timestamp_attrs(now, created_at = nil)
  {
    created_at: created_at || now,
    updated_at: now
  }
end

def build_existing_map(records)
  records.index_by { yield _1 }
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

def composite_key(*parts)
  parts
end

def upsert_rows!(model, rows, unique_by:)
  return if rows.empty?

  model.upsert_all(rows, unique_by:)
end

def sample_source_root
  @sample_source_root ||= EXTERNAL_SAMPLE_ROOT if EXTERNAL_SAMPLE_ROOT.directory?
end

def project_code_for_sample_set(sample_set_key)
  normalized = sample_set_key.to_s.parameterize(separator: "_").upcase
  base = normalized.presence || "SAMPLE"
  suffix = Digest::SHA1.hexdigest(sample_set_key.to_s)[0, 6].upcase

  "EXT_#{base.first(12)}_#{suffix}"
end

def slug_for_name(name)
  name.to_s.parameterize.presence || "sample-#{Digest::SHA1.hexdigest(name.to_s)[0, 8]}"
end

def version_label_for_name(name)
  slug_for_name(name)
end

def site_build_path_for_document(document_spec)
  File.join(
    "external_samples",
    slug_for_name(document_spec[:project_name]),
    document_spec[:slug],
    document_spec[:version_label]
  )
end

def child_directories(path)
  path.children.select(&:directory?).sort_by(&:to_s)
end

def external_sample_documents(root)
  return [] unless root&.directory?

  child_directories(root).flat_map do |sample_set_dir|
    document_dirs = child_directories(sample_set_dir)
    document_dirs = [sample_set_dir] if document_dirs.empty?

    document_dirs.map do |source_dir|
      sample_set_key = sample_set_dir.basename.to_s
      document_key = source_dir.basename.to_s

      {
        project_code: project_code_for_sample_set(sample_set_key),
        project_name: sample_set_key,
        project_description: "external_samples/#{sample_set_key} 配下のサンプル文書",
        title: document_key,
        slug: slug_for_name(document_key),
        version_label: version_label_for_name(document_key),
        source_commit_hash: "external-#{slug_for_name("#{sample_set_key}-#{document_key}")}",
        source_dir:
      }
    end
  end
end

def relative_path(path, root)
  Pathname(path).relative_path_from(Pathname(root)).to_s
end

def external_storage_key(source_file)
  relative_path(source_file, Rails.root.join("storage", "document_files"))
end

def content_type_for(path)
  extension = File.extname(path).downcase
  return "text/markdown" if %w[.md .markdown].include?(extension)

  Rack::Mime.mime_type(extension, "application/octet-stream")
end

def seed_public_id(prefix, *parts)
  raw_key = parts.flatten.map { _1.to_s.presence || "-" }.join(":")
  "#{prefix}_#{Digest::SHA256.hexdigest(raw_key)[0, 20]}"
end

def public_id_for_seed(existing, prefix, *parts)
  existing&.public_id || seed_public_id(prefix, *parts)
end

now = Time.current

company_rows = csv_rows("companies.csv")
user_rows = csv_rows("users.csv")
project_rows = csv_rows("projects.csv")
membership_rows = csv_rows("project_memberships.csv")
document_rows = csv_rows("documents.csv")
version_rows = csv_rows("document_versions.csv")
file_rows = csv_rows("document_files.csv")
permission_rows = csv_rows("document_permissions.csv")
access_log_rows = csv_rows("access_logs.csv")

project_code_by_document_slug = document_rows.each_with_object({}) do |row, result|
  result[row["slug"]] = row["project_code"]
end

ActiveRecord::Base.transaction do
  existing_companies = build_existing_map(Company.all) { [_1.code] }
  upsert_rows!(
    Company,
    company_rows.map do |row|
      existing = existing_companies[[row["code"]]]

      {
        public_id: public_id_for_seed(existing, "com", row["code"]),
        code: row["code"],
        name: row["name"],
        active: bool_value(row["active"])
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :index_companies_on_code
  )
  companies = Company.all.index_by(&:code)

  existing_users = build_existing_map(User.all) { [_1.email_address] }
  upsert_rows!(
    User,
    user_rows.map do |row|
      existing = existing_users[[row["email_address"]]]

      {
        public_id: public_id_for_seed(existing, "usr", row["email_address"]),
        email_address: row["email_address"],
        name: row["name"],
        user_type: User.user_types.fetch(row["user_type"]),
        company_id: companies.fetch(row["company_code"]).id,
        password_digest: BCrypt::Password.create(row["password"]),
        active: bool_value(row["active"])
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :index_users_on_email_address
  )
  users = User.all.index_by(&:email_address)

  existing_projects = build_existing_map(Project.all) { [_1.code] }
  upsert_rows!(
    Project,
    project_rows.map do |row|
      existing = existing_projects[[row["code"]]]

      {
        public_id: public_id_for_seed(existing, "prj", row["code"]),
        code: row["code"],
        name: row["name"],
        description: row["description"],
        active: bool_value(row["active"])
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :index_projects_on_code
  )
  projects = Project.all.index_by(&:code)

  existing_memberships = build_existing_map(ProjectMembership.all) { composite_key(_1.project_id, _1.user_id) }
  upsert_rows!(
    ProjectMembership,
    membership_rows.map do |row|
      project_id = projects.fetch(row["project_code"]).id
      user_id = users.fetch(row["user_email"]).id
      existing = existing_memberships[composite_key(project_id, user_id)]

      {
        public_id: public_id_for_seed(existing, "pmem", row["project_code"], row["user_email"]),
        project_id:,
        user_id:,
        role: ProjectMembership.roles.fetch(row["role"])
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :index_project_memberships_on_project_id_and_user_id
  )

  existing_documents = build_existing_map(Document.all) { composite_key(_1.project_id, _1.slug) }
  upsert_rows!(
    Document,
    document_rows.map do |row|
      project_id = projects.fetch(row["project_code"]).id
      existing = existing_documents[composite_key(project_id, row["slug"])]

      {
        public_id: public_id_for_seed(existing, "doc", row["project_code"], row["slug"]),
        project_id:,
        title: row["title"],
        slug: row["slug"],
        category: Document.categories.fetch(row["category"]),
        document_kind: Document.document_kinds.fetch(row["document_kind"]),
        visibility_policy: Document.visibility_policies.fetch(row["visibility_policy"])
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :index_documents_on_project_id_and_slug
  )
  documents = Document.includes(:project).index_by { composite_key(_1.project.code, _1.slug) }

  existing_versions = build_existing_map(DocumentVersion.all) { composite_key(_1.document_id, _1.version_label) }
  upsert_rows!(
    DocumentVersion,
    version_rows.map do |row|
      project_code = project_code_by_document_slug.fetch(row["document_slug"])
      document_id = documents.fetch(composite_key(project_code, row["document_slug"])).id
      existing = existing_versions[composite_key(document_id, row["version_label"])]

      {
        public_id: public_id_for_seed(existing, "ver", project_code, row["document_slug"], row["version_label"]),
        document_id:,
        version_label: row["version_label"],
        status: DocumentVersion.statuses.fetch(row["status"]),
        source_commit_hash: row["source_commit_hash"],
        changelog_summary: row["changelog_summary"],
        published_at: parse_time(row["published_at"]),
        published_by_user_id: row["published_by_email"].present? ? users.fetch(row["published_by_email"]).id : nil,
        markdown_entry_path: row["markdown_entry_path"].presence,
        site_build_path: row["site_build_path"].presence,
        pdf_snapshot_path: row["pdf_snapshot_path"].presence
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :index_document_versions_on_document_id_and_version_label
  )
  versions = DocumentVersion.includes(document: :project).index_by { composite_key(_1.document.project.code, _1.document.slug, _1.version_label) }

  upsert_rows!(
    Document,
    document_rows.filter_map do |row|
      next if row["latest_version_label"].blank?

      document = documents.fetch(composite_key(row["project_code"], row["slug"]))
      latest_version = versions.fetch(composite_key(row["project_code"], row["slug"], row["latest_version_label"]))

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
      }.merge(timestamp_attrs(now, document.created_at))
    end,
    unique_by: :id
  )

  existing_files = build_existing_map(DocumentFile.all) { [_1.storage_key] }
  upsert_rows!(
    DocumentFile,
    file_rows.map do |row|
      project_code = project_code_by_document_slug.fetch(row["document_slug"])
      version = versions.fetch(composite_key(project_code, row["document_slug"], row["version_label"]))
      existing = existing_files[[row["storage_key"]]]

      {
        public_id: public_id_for_seed(existing, "file", row["storage_key"]),
        document_version_id: version.id,
        file_name: row["file_name"],
        content_type: row["content_type"],
        storage_key: row["storage_key"],
        file_size: row["file_size"].to_i,
        sort_order: row["sort_order"].to_i
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :index_document_files_on_storage_key
  )

  existing_permissions = build_existing_map(DocumentPermission.all) do
    composite_key(_1.document_id, _1.company_id, _1.user_id)
  end

  permission_keys = permission_rows.map do |row|
    project_code = project_code_by_document_slug.fetch(row["document_slug"])
    document_id = documents.fetch(composite_key(project_code, row["document_slug"])).id
    company_id = row["company_code"].present? ? companies.fetch(row["company_code"]).id : nil
    user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil

    composite_key(document_id, company_id, user_id)
  end

  permission_ids = next_seed_ids(existing_permissions, permission_keys)

  upsert_rows!(
    DocumentPermission,
    permission_rows.each_with_index.map do |row, index|
      project_code = project_code_by_document_slug.fetch(row["document_slug"])
      document_id = documents.fetch(composite_key(project_code, row["document_slug"])).id
      company_id = row["company_code"].present? ? companies.fetch(row["company_code"]).id : nil
      user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil
      existing = existing_permissions[composite_key(document_id, company_id, user_id)]

      {
        id: permission_ids[index],
        public_id: public_id_for_seed(
          existing,
          "perm",
          project_code,
          row["document_slug"],
          row["company_code"],
          row["user_email"]
        ),
        document_id:,
        company_id:,
        user_id:,
        access_level: DocumentPermission.access_levels.fetch(row["access_level"])
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :id
  )

  existing_access_logs = build_existing_map(AccessLog.all) do
    composite_key(
      _1.project_id, _1.document_id, _1.document_version_id, _1.user_id, _1.company_id,
      _1.action_type_before_type_cast, _1.target_type, _1.target_name, _1.ip_address, _1.user_agent, _1.accessed_at
    )
  end

  access_log_keys = access_log_rows.map do |row|
    project_code = row["project_code"]
    document = documents.fetch(composite_key(project_code, row["document_slug"]))
    version = versions.fetch(composite_key(project_code, row["document_slug"], row["version_label"]))
    user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil
    company_id = row["company_code"].present? ? companies.fetch(row["company_code"]).id : nil
    accessed_at = parse_time(row["accessed_at"])

    composite_key(
      projects.fetch(project_code).id, document.id, version.id, user_id, company_id,
      AccessLog.action_types.fetch(row["action_type"]), row["target_type"], row["target_name"],
      row["ip_address"], row["user_agent"], accessed_at
    )
  end

  access_log_ids = next_seed_ids(existing_access_logs, access_log_keys)

  upsert_rows!(
    AccessLog,
    access_log_rows.each_with_index.map do |row, index|
      project_code = row["project_code"]
      document = documents.fetch(composite_key(project_code, row["document_slug"]))
      version = versions.fetch(composite_key(project_code, row["document_slug"], row["version_label"]))
      user_id = row["user_email"].present? ? users.fetch(row["user_email"]).id : nil
      company_id = row["company_code"].present? ? companies.fetch(row["company_code"]).id : nil
      accessed_at = parse_time(row["accessed_at"])
      action_type = AccessLog.action_types.fetch(row["action_type"])

      existing = existing_access_logs[composite_key(
        projects.fetch(project_code).id, document.id, version.id, user_id, company_id,
        action_type, row["target_type"], row["target_name"], row["ip_address"], row["user_agent"], accessed_at
      )]

      {
        id: access_log_ids[index],
        public_id: public_id_for_seed(
          existing,
          "alog",
          row["project_code"],
          row["document_slug"],
          row["version_label"],
          row["user_email"],
          row["company_code"],
          row["action_type"],
          row["target_type"],
          row["target_name"],
          row["ip_address"],
          row["user_agent"],
          row["accessed_at"]
        ),
        project_id: projects.fetch(project_code).id,
        document_id: document.id,
        document_version_id: version.id,
        user_id:,
        company_id:,
        action_type:,
        target_type: row["target_type"],
        target_name: row["target_name"],
        ip_address: row["ip_address"],
        user_agent: row["user_agent"],
        accessed_at:
      }.merge(timestamp_attrs(now, existing&.created_at))
    end,
    unique_by: :id
  )

  sample_documents = external_sample_documents(sample_source_root)

  if sample_documents.any?
    upsert_rows!(
      Project,
      sample_documents.uniq { _1[:project_code] }.map do |document_spec|
        existing_project = existing_projects[[document_spec[:project_code]]]

        {
          public_id: public_id_for_seed(existing_project, "prj", document_spec[:project_code]),
          code: document_spec[:project_code],
          name: document_spec[:project_name],
          description: document_spec[:project_description],
          active: true
        }.merge(timestamp_attrs(now, existing_project&.created_at))
      end,
      unique_by: :index_projects_on_code
    )
    projects = Project.all.index_by(&:code)

    existing_documents = build_existing_map(Document.all) { composite_key(_1.project_id, _1.slug) }

    external_document_rows = sample_documents.map do |document_spec|
      project = projects.fetch(document_spec[:project_code])
      existing = existing_documents[composite_key(project.id, document_spec[:slug])]

      {
        public_id: public_id_for_seed(existing, "doc", document_spec[:project_code], document_spec[:slug]),
        project_id: project.id,
        title: document_spec[:title],
        slug: document_spec[:slug],
        category: Document.categories.fetch("spec"),
        document_kind: Document.document_kinds.fetch("mixed"),
        visibility_policy: Document.visibility_policies.fetch("restricted_external")
      }.merge(timestamp_attrs(now, existing&.created_at))
    end
    upsert_rows!(Document, external_document_rows, unique_by: :index_documents_on_project_id_and_slug)
    documents = Document.includes(:project).index_by { composite_key(_1.project.code, _1.slug) }

    existing_versions = build_existing_map(DocumentVersion.all) { composite_key(_1.document_id, _1.version_label) }

    external_version_rows = sample_documents.map do |document_spec|
      document = documents.fetch(composite_key(document_spec[:project_code], document_spec[:slug]))
      existing = existing_versions[composite_key(document.id, document_spec[:version_label])]
      site_build_path = site_build_path_for_document(document_spec)
      markdown_entry_path = Dir.glob(document_spec[:source_dir].join("**/*").to_s).find do |path|
        File.file?(path) && %w[.md .markdown].include?(File.extname(path).downcase)
      end

      {
        public_id: public_id_for_seed(existing, "ver", document_spec[:project_code], document_spec[:slug], document_spec[:version_label]),
        document_id: document.id,
        version_label: document_spec[:version_label],
        status: DocumentVersion.statuses.fetch("published"),
        source_commit_hash: document_spec[:source_commit_hash],
        changelog_summary: "#{document_spec[:title]} を external_samples から取り込み",
        published_at: now,
        published_by_user_id: users.fetch("admin@example.com").id,
        notes: "source_dir=#{document_spec[:source_dir]}",
        markdown_entry_path: markdown_entry_path ? site_build_path : nil,
        site_build_path: markdown_entry_path ? site_build_path : nil,
        pdf_snapshot_path: nil
      }.merge(timestamp_attrs(now, existing&.created_at))
    end
    upsert_rows!(DocumentVersion, external_version_rows, unique_by: :index_document_versions_on_document_id_and_version_label)
    versions = DocumentVersion.includes(document: :project).index_by { composite_key(_1.document.project.code, _1.document.slug, _1.version_label) }

    upsert_rows!(
      Document,
      sample_documents.map do |document_spec|
        document = documents.fetch(composite_key(document_spec[:project_code], document_spec[:slug]))
        version = versions.fetch(composite_key(document_spec[:project_code], document_spec[:slug], document_spec[:version_label]))

        {
          id: document.id,
          public_id: document.public_id,
          project_id: document.project_id,
          title: document.title,
          slug: document.slug,
          category: document.category_before_type_cast,
          document_kind: document.document_kind_before_type_cast,
          visibility_policy: document.visibility_policy_before_type_cast,
          latest_version_id: version.id
        }.merge(timestamp_attrs(now, document.created_at))
      end,
      unique_by: :id
    )

    versions = DocumentVersion.includes(document: :project).index_by { composite_key(_1.document.project.code, _1.document.slug, _1.version_label) }

    sample_documents.each do |document_spec|
      version = versions.fetch(composite_key(document_spec[:project_code], document_spec[:slug], document_spec[:version_label]))
      next if version.site_build_path.blank?

      SeedSupport::DocusaurusBuilder.new(
        source_dir: document_spec[:source_dir],
        version: version,
        site_build_path: version.site_build_path
      ).build
    end

    existing_files = build_existing_map(DocumentFile.all) { [_1.storage_key] }

    external_file_specs = sample_documents.flat_map do |document_spec|
      version = versions.fetch(composite_key(document_spec[:project_code], document_spec[:slug], document_spec[:version_label]))
      source_files = Dir.glob(document_spec[:source_dir].join("**/*").to_s).select { File.file?(_1) }.sort

      source_files.each_with_index.map do |source_file, index|
        storage_key = external_storage_key(source_file)
        existing = existing_files[[storage_key]]

        {
          row: {
            public_id: public_id_for_seed(existing, "file", storage_key),
            document_version_id: version.id,
            file_name: relative_path(source_file, document_spec[:source_dir]),
            content_type: content_type_for(source_file),
            storage_key: storage_key,
            file_size: File.size(source_file),
            sort_order: index
          }.merge(timestamp_attrs(now, existing&.created_at))
        }
      end
    end

    upsert_rows!(
      DocumentFile,
      external_file_specs.map { _1[:row] },
      unique_by: :index_document_files_on_storage_key
    )

    external_company_codes = user_rows.select { _1["user_type"] == "external" }.map { _1["company_code"] }.uniq
    existing_permissions = build_existing_map(DocumentPermission.all) do
      composite_key(_1.document_id, _1.company_id, _1.user_id)
    end

    external_permission_keys = sample_documents.flat_map do |document_spec|
      document = documents.fetch(composite_key(document_spec[:project_code], document_spec[:slug]))

      external_company_codes.map do |company_code|
        company_id = companies.fetch(company_code).id
        composite_key(document.id, company_id, nil)
      end
    end

    external_permission_ids = next_seed_ids(existing_permissions, external_permission_keys)

    external_permission_rows = sample_documents.flat_map do |document_spec|
      document = documents.fetch(composite_key(document_spec[:project_code], document_spec[:slug]))

      external_company_codes.map do |company_code|
        company_id = companies.fetch(company_code).id
        existing = existing_permissions[composite_key(document.id, company_id, nil)]

        {
          id: nil,
          public_id: public_id_for_seed(
            existing,
            "perm",
            document_spec[:project_code],
            document_spec[:slug],
            company_code,
            nil
          ),
          document_id: document.id,
          company_id: company_id,
          user_id: nil,
          access_level: DocumentPermission.access_levels.fetch("download")
        }.merge(timestamp_attrs(now, existing&.created_at))
      end
    end

    external_permission_rows.each_with_index do |row, index|
      row[:id] = external_permission_ids[index]
    end

    upsert_rows!(
      DocumentPermission,
      external_permission_rows,
      unique_by: :id
    )
  else
    puts "External sample directories not found under storage/document_files/external_samples. Skipped external sample files."
  end
end

%w[
  access_logs
  document_permissions
].each do |table_name|
  ActiveRecord::Base.connection.reset_pk_sequence!(table_name)
end

puts "Seed complete."
puts "admin@example.com / password123!"
puts "staff@example.com / password123!"
puts "client-a@example.com / password123!"
puts "client-b@example.com / password123!"
