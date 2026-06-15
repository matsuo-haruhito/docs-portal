require "rails_helper"
require "fileutils"
require "stringio"
require "tmpdir"

load Rails.root.join("bin/verify_backup_artifacts")

RSpec.describe BackupArtifactVerifier do
  around do |example|
    Dir.mktmpdir("backup-artifact-verifier") do |dir|
      @tmpdir = Pathname.new(dir)
      example.run
    end
  end

  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }
  let(:db_dump) { tmpdir.join("prod-db-20260613-abcdef1.dump") }
  let(:storage_archive) { tmpdir.join("docs-portal-production-20260613-abcdef1.tar") }
  let(:pg_restore_command) { fake_command("pg-restore-list", "database/table\n") }
  let(:tar_command) { fake_command("tar-list", tar_listing) }
  let(:tar_listing) do
    <<~LISTING
      ./storage/document_files/project-a/file.pdf
      storage/docs_sites/project-a/index.html
    LISTING
  end

  def tmpdir
    @tmpdir
  end

  def touch(path)
    FileUtils.mkdir_p(path.dirname)
    FileUtils.touch(path)
  end

  def fake_command(name, output, exit_status: 0)
    path = tmpdir.join(name)
    path.write(<<~RUBY)
      #!/usr/bin/env ruby
      STDOUT.write(#{output.inspect})
      exit #{exit_status}
    RUBY
    File.chmod(0o755, path)
    path.to_s
  end

  def verify_db_dump(db_dump: self.db_dump, format: :text, pg_restore: pg_restore_command)
    touch(db_dump)

    described_class.new(
      db_dump: db_dump.to_s,
      storage_archive: nil,
      manifest: nil,
      strict_metadata: false,
      format:,
      pg_restore:,
      stdout:,
      stderr:
    ).call
  end

  def verify(storage_archive: self.storage_archive, strict_metadata: false, format: :text, tar: tar_command)
    touch(storage_archive)

    described_class.new(
      db_dump: nil,
      storage_archive: storage_archive.to_s,
      manifest: nil,
      strict_metadata:,
      format:,
      tar:,
      stdout:,
      stderr:
    ).call
  end

  it "passes when the DB dump list is readable" do
    result = verify_db_dump

    expect(result.ok).to be(true)
    expect(result.warnings).to be_empty
    expect(stdout.string).to include("Checking DB dump with pg_restore --list: #{db_dump}")
    expect(stdout.string).to include("DB dump list is readable.")
    expect(stdout.string).to include("Backup artifact verification completed.")
    expect(stderr.string).to be_empty
  end

  it "fails when pg_restore cannot list the DB dump" do
    failing_pg_restore = fake_command("pg-restore-failure", "pg_restore: error: input file does not appear to be a valid archive\n", exit_status: 1)

    result = verify_db_dump(pg_restore: failing_pg_restore)

    expect(result.ok).to be(false)
    expect(stdout.string).to include("Checking DB dump with pg_restore --list: #{db_dump}")
    expect(stderr.string).to include("pg_restore --list failed for #{db_dump}: pg_restore: error: input file does not appear to be a valid archive")
    expect(stderr.string).to include("docs/バックアップ・リストア手順.md")
  end

  it "fails when pg_restore is not available" do
    result = verify_db_dump(pg_restore: tmpdir.join("missing-pg_restore").to_s)

    expect(result.ok).to be(false)
    expect(stderr.string).to include("pg_restore executable not found; install PostgreSQL client tools or run on a host that has pg_restore")
    expect(stderr.string).to include("docs/バックアップ・リストア手順.md")
  end

  it "passes when the storage archive contains the required prefixes and metadata" do
    result = verify

    expect(result.ok).to be(true)
    expect(result.warnings).to be_empty
    expect(stdout.string).to include("Storage archive includes storage/document_files and storage/docs_sites.")
    expect(stderr.string).to be_empty
  end

  it "fails when the storage archive is missing a required prefix" do
    missing_docs_sites_tar = fake_command("missing-docs-sites", "storage/document_files/project-a/file.pdf\n")

    result = verify(tar: missing_docs_sites_tar)

    expect(result.ok).to be(false)
    expect(stderr.string).to include("storage archive is missing required paths: storage/docs_sites")
  end

  it "warns about missing metadata in normal mode" do
    archive_without_metadata = tmpdir.join("backup.tar")

    result = verify(storage_archive: archive_without_metadata)

    expect(result.ok).to be(true)
    expect(result.warnings).to contain_exactly(
      "metadata naming is missing environment name, timestamp, commit SHA or release identifier; include these in artifact names or --manifest"
    )
    expect(stdout.string).to include("Backup artifact verification completed with warnings.")
    expect(stdout.string).to include("WARNING: metadata naming is missing environment name, timestamp, commit SHA or release identifier")
  end

  it "fails on missing metadata in strict mode" do
    archive_without_metadata = tmpdir.join("backup.tar")

    result = verify(storage_archive: archive_without_metadata, strict_metadata: true)

    expect(result.ok).to be(false)
    expect(stderr.string).to include("metadata naming is missing environment name, timestamp, commit SHA or release identifier")
  end

  it "prints a markdown release-record summary when requested" do
    result = verify(format: :markdown)

    expect(result.ok).to be(true)
    expect(result.summary).to include(
      storage_archive: storage_archive.to_s,
      storage_archive_status: "readable",
      required_storage_prefixes_status: "present",
      metadata_status: "ok",
      overall_result: "ok"
    )
    expect(stdout.string).to include("### Backup artifact verification summary")
    expect(stdout.string).to include("- storage archive: #{storage_archive}")
    expect(stdout.string).to include("- required storage prefixes (storage/document_files, storage/docs_sites): present")
    expect(stdout.string).to include("- metadata: ok")
    expect(stdout.string).to include("- warnings: none")
    expect(stdout.string).to include("- overall result: ok")
  end

  it "includes metadata warnings in the markdown summary without changing warning semantics" do
    archive_without_metadata = tmpdir.join("backup.tar")

    result = verify(storage_archive: archive_without_metadata, format: :markdown)

    expect(result.ok).to be(true)
    expect(result.warnings).to contain_exactly(
      "metadata naming is missing environment name, timestamp, commit SHA or release identifier; include these in artifact names or --manifest"
    )
    expect(stdout.string).to include("- metadata: warning: environment name, timestamp, commit SHA or release identifier")
    expect(stdout.string).to include("- warnings: metadata naming is missing environment name, timestamp, commit SHA or release identifier; include these in artifact names or --manifest")
    expect(stdout.string).to include("- overall result: warning")
  end

  it "prints a markdown failure summary when requested" do
    failing_pg_restore = fake_command("pg-restore-failure", "pg_restore: error: input file does not appear to be a valid archive\n", exit_status: 1)

    result = verify_db_dump(format: :markdown, pg_restore: failing_pg_restore)

    expect(result.ok).to be(false)
    expect(result.summary).to include(
      db_dump_status: "failed",
      overall_result: "failed"
    )
    expect(stdout.string).to include("### Backup artifact verification summary")
    expect(stdout.string).to include("- DB dump read: failed")
    expect(stdout.string).to include("- overall result: failed")
    expect(stdout.string).to include("- failure: pg_restore --list failed for #{db_dump}: pg_restore: error: input file does not appear to be a valid archive")
  end
end
