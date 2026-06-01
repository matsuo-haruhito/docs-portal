require "rails_helper"

RSpec.describe ApplicationConfigurationDiagnostic do
  around do |example|
    Dir.mktmpdir("application-configuration-diagnostic") do |root|
      @root = Pathname(root)
      write_storage_config
      FileUtils.mkdir_p(@root.join("storage", "document_files"))
      FileUtils.mkdir_p(@root.join("docusaurus"))
      @root.join("docusaurus", "package.json").write("{}\n")

      example.run
    end
  end

  let(:root) { @root }
  let(:rails_env) { ActiveSupport::StringInquirer.new("development") }
  let(:env) { valid_env }

  def valid_env
    {
      "DATABASE_HOST" => "db",
      "DATABASE_PORT" => "5432",
      "DATABASE_USER" => "docs_portal",
      "DATABASE_NAME" => "docs_portal_test",
      "DATABASE_PASSWORD" => "password",
      "ACTIVE_STORAGE_SERVICE" => "local",
      "PUBLISH_WEB_SERVER_PORT" => "3030",
      "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => "primary-key",
      "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => "deterministic-key",
      "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => "derivation-salt",
      "SECRET_KEY_BASE" => "x" * 40,
      "RAILS_MASTER_KEY" => "master-key",
      "DOC_IMPORT_TOKEN" => "import-token",
      "KROKI_ENDPOINT" => "http://kroki:8000"
    }
  end

  def call_diagnostic(env: self.env, rails_env: self.rails_env)
    described_class.new(env:, root:, rails_env:).call
  end

  def check_for(result, key, status: nil)
    checks = result.checks.select { |check| check.key == key }
    checks = checks.select { |check| check.status == status } if status
    expect(checks).not_to be_empty
    checks.first
  end

  def write_storage_config
    @root.join("config").mkpath
    @root.join("config", "storage.yml").write(<<~YAML)
      local:
        service: Disk
        root: <%= Rails.root.join("storage") %>
    YAML
  end

  it "aggregates healthy environment, secret, storage, and workspace checks" do
    result = call_diagnostic

    expect(result).to be_healthy
    expect(result.error_count).to eq(0)
    expect(result.warning_count).to eq(0)
    expect(result.ok_count).to eq(result.checks.size)

    expect(result.checks.map(&:key)).to include(
      "DATABASE_HOST",
      "SECRET_KEY_BASE",
      "ACTIVE_STORAGE_SERVICE",
      "document_files storage root",
      "docusaurus.workspace",
      "KROKI_ENDPOINT"
    )
  end

  it "reports missing required environment variables as errors" do
    result = call_diagnostic(env: valid_env.merge("DATABASE_HOST" => " "))

    check = check_for(result, "DATABASE_HOST", status: :error)

    expect(check.label).to eq("DATABASE_HOST is missing")
    expect(result.error_count).to eq(1)
    expect(result).not_to be_healthy
  end

  it "keeps development sample secrets at warning level without exposing secret values" do
    result = call_diagnostic(
      env: valid_env.merge(
        "SECRET_KEY_BASE" => "secret",
        "RAILS_MASTER_KEY" => "replace_me",
        "DOC_IMPORT_TOKEN" => "local-dev-import-token"
      ),
      rails_env: ActiveSupport::StringInquirer.new("development")
    )

    sample_secret_checks = [
      check_for(result, "SECRET_KEY_BASE"),
      check_for(result, "RAILS_MASTER_KEY"),
      check_for(result, "DOC_IMPORT_TOKEN")
    ]

    expect(sample_secret_checks.map(&:status)).to eq([:warning, :warning, :warning])
    expect(sample_secret_checks.map(&:detail)).to all(be_nil)
    expect(result.error_count).to eq(0)
    expect(result.warning_count).to eq(3)
    expect(result).to be_healthy
  end

  it "raises production sample secrets to errors" do
    result = call_diagnostic(
      env: valid_env.merge(
        "SECRET_KEY_BASE" => "secret",
        "RAILS_MASTER_KEY" => "replace_me",
        "DOC_IMPORT_TOKEN" => "local-dev-import-token"
      ),
      rails_env: ActiveSupport::StringInquirer.new("production")
    )

    expect(check_for(result, "SECRET_KEY_BASE").status).to eq(:error)
    expect(check_for(result, "RAILS_MASTER_KEY").status).to eq(:error)
    expect(check_for(result, "DOC_IMPORT_TOKEN").status).to eq(:error)
    expect(result.error_count).to eq(3)
    expect(result).not_to be_healthy
  end
end
