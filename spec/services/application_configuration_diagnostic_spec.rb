require "rails_helper"
require "fileutils"

RSpec.describe ApplicationConfigurationDiagnostic do
  FakeEnv = Struct.new(:value) do
    def production?
      value == "production"
    end
  end

  let(:root) { Rails.root.join("tmp", "config-diagnostic-spec") }
  let(:env) do
    {
      "DATABASE_HOST" => "db",
      "DATABASE_PORT" => "5432",
      "DATABASE_USER" => "postgres",
      "DATABASE_NAME" => "docs_portal",
      "DATABASE_PASSWORD" => "password",
      "ACTIVE_STORAGE_SERVICE" => "local",
      "PUBLISH_WEB_SERVER_PORT" => "3000",
      "RAILS_MAX_THREADS" => "5",
      "SECRET_KEY_BASE" => "#{"x" * 40}",
      "RAILS_MASTER_KEY" => "#{"y" * 32}",
      "DOC_IMPORT_TOKEN" => "#{"z" * 32}",
      "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" => "#{"a" * 32}",
      "ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY" => "#{"b" * 32}",
      "ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT" => "#{"c" * 32}",
      "COMPOSE_FILE" => "docker-compose.yml"
    }
  end

  before do
    FileUtils.mkdir_p(root.join("config"))
    FileUtils.mkdir_p(root.join("storage", "document_files"))
    FileUtils.mkdir_p(root.join("docusaurus"))

    root.join("config", "storage.yml").write(<<~YAML)
      local:
        service: Disk
        root: storage
    YAML
    root.join("docusaurus", "package.json").write("{}")
  end

  after do
    FileUtils.rm_rf(root)
  end

  it "returns ok checks for a valid local configuration" do
    result = described_class.new(env:, root:, rails_env: FakeEnv.new("development")).call

    expect(result.error_count).to eq(0)
    expect(result.ok_count).to be_positive
    expect(result).to be_healthy
  end

  it "reports missing required environment variables as errors" do
    env.delete("DATABASE_HOST")

    result = described_class.new(env:, root:, rails_env: FakeEnv.new("development")).call

    expect(result.error_count).to eq(1)
    expect(result.checks.find { _1.key == "DATABASE_HOST" }).to be_error
  end

  it "reports missing Active Record Encryption variables as errors" do
    env.delete("ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY")

    result = described_class.new(env:, root:, rails_env: FakeEnv.new("development")).call

    expect(result.error_count).to eq(1)
    expect(result.checks.find { _1.key == "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY" }).to be_error
  end

  it "reports invalid numeric environment variables as errors" do
    env["DATABASE_PORT"] = "postgres"

    result = described_class.new(env:, root:, rails_env: FakeEnv.new("development")).call

    check = result.checks.find { _1.key == "DATABASE_PORT" && _1.label.include?("must be numeric") }
    expect(check).to be_error
  end

  it "rejects development sample secrets in production" do
    env["SECRET_KEY_BASE"] = "secret"
    env["RAILS_MASTER_KEY"] = "replace_me"
    env["DOC_IMPORT_TOKEN"] = "local-dev-import-token"

    result = described_class.new(env:, root:, rails_env: FakeEnv.new("production")).call

    expect(result.error_count).to eq(3)
    expect(result.checks.select(&:error?).map(&:key)).to include("SECRET_KEY_BASE", "RAILS_MASTER_KEY", "DOC_IMPORT_TOKEN")
  end

  it "reports undefined active storage services" do
    env["ACTIVE_STORAGE_SERVICE"] = "gcs"

    result = described_class.new(env:, root:, rails_env: FakeEnv.new("development")).call

    check = result.checks.find { _1.key == "ACTIVE_STORAGE_SERVICE" && _1.label.include?("not defined") }
    expect(check).to be_error
  end

  it "requires a Kroki endpoint when the optional Kroki compose file is enabled" do
    env["COMPOSE_FILE"] = "docker-compose.yml:docker-compose.kroki.yml"
    env.delete("KROKI_ENDPOINT")

    result = described_class.new(env:, root:, rails_env: FakeEnv.new("development")).call

    expect(result.checks.find { _1.key == "KROKI_ENDPOINT" }).to be_error
  end
end
