class BuildFreshnessGuard
  def initialize(source_path:, build_entry_path:, marker_path:, job_class:)
    @source_path = Pathname.new(source_path)
    @build_entry_path = Pathname.new(build_entry_path)
    @marker_path = Pathname.new(marker_path)
    @job_class = job_class
  end

  def stale?
    return true unless build_entry_path.exist?
    return false unless source_path.exist?

    source_path.mtime > build_entry_path.mtime
  end

  def build_requested?
    marker_path.exist?
  end

  def request_build!
    FileUtils.mkdir_p(marker_path.dirname)
    File.write(marker_path, Time.current.iso8601)
  end

  def clear_build_request!
    FileUtils.rm_f(marker_path)
  end

  def enqueue_if_stale!
    return false unless stale?
    return false if build_requested?

    request_build!
    job_class.perform_later
    true
  end

  private

  attr_reader :source_path, :build_entry_path, :marker_path, :job_class
end
