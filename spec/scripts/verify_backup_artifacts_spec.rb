# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "open3"
require "tmpdir"

RSpec.describe "bin/verify_backup_artifacts" do
  let(:repo_root) { File.expand_path("../..", __dir__) }
  let(:script_path) { File.join(repo_root, "bin/verify_backup_artifacts") }

  def run_command(*args, env: {})
    Open3.capture3(env, "ruby", script_path, *args)
  end

  it "verifies a readable dump list and storage archive without restoring data" do
    Dir.mktmpdir do |dir|
      fake_bin = File.join(dir, "bin")
      FileUtils.mkdir_p(fake_bin)
      pg_restore = File.join(fake_bin, "pg_restore")
      File.write(pg_restore, "#!/bin/sh\nexit 0\n")
      FileUtils.chmod("+x", pg_restore)

      dump = File.join(dir, "prod-db-20260612T041200Z-abcdef1.dump")
      File.write(dump, "stub")

      storage_root = File.join(dir, "storage")
      FileUtils.mkdir_p(File.join(storage_root, "document_files"))
      FileUtils.mkdir_p(File.join(storage_root, "docs_sites"))
      File.write(File.join(storage_root, "document_files", "keep"), "ok")
      File.write(File.join(storage_root, "docs_sites", "keep"), "ok")
      archive = File.join(dir, "prod-storage-20260612T041200Z-abcdef1.tar")
      system("tar", "-cf", archive, "-C", dir, "storage")

      stdout, stderr, status = run_command(
        "--db-dump", dump,
        "--storage-archive", archive,
        env: { "PATH" => "#{fake_bin}:#{ENV.fetch('PATH')}" }
      )

      expect(status).to be_success
      expect(stdout).to include("DB dump list is readable.")
      expect(stdout).to include("Storage archive includes storage/document_files and storage/docs_sites.")
      expect(stdout).to include("Backup artifact verification completed.")
      expect(stderr).to be_empty
    end
  end

  it "prints a markdown summary through the CLI option" do
    Dir.mktmpdir do |dir|
      fake_bin = File.join(dir, "bin")
      FileUtils.mkdir_p(fake_bin)
      pg_restore = File.join(fake_bin, "pg_restore")
      File.write(pg_restore, "#!/bin/sh\nexit 0\n")
      FileUtils.chmod("+x", pg_restore)

      dump = File.join(dir, "prod-db-20260612T041200Z-abcdef1.dump")
      File.write(dump, "stub")

      storage_root = File.join(dir, "storage")
      FileUtils.mkdir_p(File.join(storage_root, "document_files"))
      FileUtils.mkdir_p(File.join(storage_root, "docs_sites"))
      File.write(File.join(storage_root, "document_files", "keep"), "ok")
      File.write(File.join(storage_root, "docs_sites", "keep"), "ok")
      archive = File.join(dir, "prod-storage-20260612T041200Z-abcdef1.tar")
      system("tar", "-cf", archive, "-C", dir, "storage")

      stdout, stderr, status = run_command(
        "--db-dump", dump,
        "--storage-archive", archive,
        "--format", "markdown",
        env: { "PATH" => "#{fake_bin}:#{ENV.fetch('PATH')}" }
      )

      expect(status).to be_success
      expect(stdout).to include("### Backup artifact verification summary")
      expect(stdout).to include("- DB dump read: readable")
      expect(stdout).to include("- storage archive read: readable")
      expect(stdout).to include("- required storage prefixes (storage/document_files, storage/docs_sites): present")
      expect(stdout).to include("- metadata: ok")
      expect(stdout).to include("- overall result: ok")
      expect(stderr).to be_empty
    end
  end

  it "fails when the storage archive is missing required top-level paths" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "storage", "imports"))
      archive = File.join(dir, "prod-storage-20260612T041200Z-abcdef1.tar")
      system("tar", "-cf", archive, "-C", dir, "storage")

      stdout, stderr, status = run_command("--storage-archive", archive)

      expect(status).not_to be_success
      expect(stdout).to include("Checking storage archive listing")
      expect(stderr).to include("storage archive is missing required paths: storage/document_files, storage/docs_sites")
      expect(stderr).to include("docs/バックアップ・リストア手順.md")
    end
  end

  it "warns when artifact names do not include restore metadata" do
    Dir.mktmpdir do |dir|
      storage_root = File.join(dir, "storage")
      FileUtils.mkdir_p(File.join(storage_root, "document_files"))
      FileUtils.mkdir_p(File.join(storage_root, "docs_sites"))
      archive = File.join(dir, "storage.tar")
      system("tar", "-cf", archive, "-C", dir, "storage")

      stdout, stderr, status = run_command("--storage-archive", archive)

      expect(status).to be_success
      expect(stdout).to include("WARNING: metadata naming is missing environment name, timestamp, commit SHA or release identifier")
      expect(stderr).to be_empty
    end
  end

  it "fails missing metadata through the strict metadata CLI option" do
    Dir.mktmpdir do |dir|
      storage_root = File.join(dir, "storage")
      FileUtils.mkdir_p(File.join(storage_root, "document_files"))
      FileUtils.mkdir_p(File.join(storage_root, "docs_sites"))
      archive = File.join(dir, "storage.tar")
      system("tar", "-cf", archive, "-C", dir, "storage")

      stdout, stderr, status = run_command("--storage-archive", archive, "--strict-metadata")

      expect(status).not_to be_success
      expect(stdout).to include("Checking storage archive listing")
      expect(stdout).to include("Storage archive includes storage/document_files and storage/docs_sites.")
      expect(stderr).to include("Backup artifact verification failed: metadata naming is missing environment name, timestamp, commit SHA or release identifier")
      expect(stderr).to include("docs/バックアップ・リストア手順.md")
    end
  end
end
