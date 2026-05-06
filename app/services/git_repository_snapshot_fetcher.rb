require "fileutils"
require "open3"
require "tmpdir"

class GitRepositorySnapshotFetcher
  Result = Data.define(:worktree_path, :commit_sha)

  def initialize(source:)
    @source = source
  end

  def call
    Dir.mktmpdir("git-import-") do |dir|
      clone_repository!(dir)
      commit_sha = git!("rev-parse", "HEAD", chdir: dir).strip
      source_path = Pathname.new(dir).join(@source.normalized_source_path)
      raise ApplicationError::BadRequest, "source_path not found in repository: #{@source.normalized_source_path}" unless source_path.directory?

      yield Result.new(worktree_path: source_path, commit_sha: commit_sha)
    end
  end

  private

  def clone_repository!(dir)
    git!("clone", "--depth", "1", "--branch", @source.branch, repository_url, dir)
  end

  def repository_url
    case @source.auth_type.to_sym
    when :fine_grained_pat
      token = @source.credential_secret.to_s
      raise ApplicationError::BadRequest, "Git credential is not configured" if token.blank?

      "https://x-access-token:#{Shellwords.escape(token)}@github.com/#{@source.repository_full_name}.git"
    when :none
      "https://github.com/#{@source.repository_full_name}.git"
    else
      raise ApplicationError::BadRequest, "#{@source.auth_type} pull sync is not implemented yet"
    end
  end

  def git!(*args, chdir: nil)
    stdout, stderr, status = Open3.capture3("git", *args, chdir: chdir)
    return stdout if status.success?

    sanitized = stderr.to_s.gsub(%r{https://[^\s@]+@github\.com}, "https://[FILTERED]@github.com")
    raise ApplicationError::BadRequest, sanitized.presence || "git command failed"
  end
end
