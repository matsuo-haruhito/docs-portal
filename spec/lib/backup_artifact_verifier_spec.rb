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
  let(:storage_archive) { tmpdir.join("docs-portal-production-20260613-abcdef1.tar") }
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

  def verify(storage_archive: self.storage_archive, strict_metadata: false, tar: tar_command)
    touch(storage_archive)

    described_class.new(
      db_dump: nil,
      storage_archive: storage_archive.to_s,
      manifest: nil,
      strict_metadata:,
      tar:,
      stdout:,
      stderr:
    ).call
  end

  it "passes when the storage archive contains the required prefixes and metadata" do
    result = verify

    expect(result).to be_ok
    expect(result.warnings).to be_empty
    expect(stdout.string).to include("Storage archive includes storage/document_files and storage/docs_sites.")
    expect(stderr.string).to be_empty
  end

  it "fails when the storage archive is missing a required prefix" do
    missing_docs_sites_tar = fake_command("missing-docs-sites", "storage/document_files/project-a/file.pdf\n")

    result = verify(tar: missing_docs_sites_tar)

    expect(result).not_to be_ok
    expect(stderr.string).to include("storage archive is missing required paths: storage/docs_sites")
  end

  it "warns about missing metadata in normal mode" do
    archive_without_metadata = tmpdir.join("backup.tar")

    result = verify(storage_archive: archive_without_metadata)

    expect(result).to be_ok
    expect(result.warnings).to contain_exactly(
      "metadata naming is missing environment name, timestamp, commit SHA or release identifier; include these in artifact names or --manifest"
    )
    expect(stdout.string).to include("Backup artifact verification completed with warnings.")
    expect(stdout.string).to include("WARNING: metadata naming is missing environment name, timestamp, commit SHA or release identifier")
  end

  it "fails on missing metadata in strict mode" do
    archive_without_metadata = tmpdir.join("backup.tar")

    result = verify(storage_archive: archive_without_metadata, strict_metadata: true)

    expect(result).not_to be_ok
    expect(stderr.string).to include("metadata naming is missing environment name, timestamp, commit SHA or release identifier")
  end
end
