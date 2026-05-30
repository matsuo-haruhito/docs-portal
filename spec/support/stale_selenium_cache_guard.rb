require "fileutils"
require "json"
require "pathname"

module StaleSeleniumCacheGuard
  DEFAULT_CACHE_ROOT = Pathname.new(ENV.fetch("SE_CACHE_PATH", File.join(Dir.home, ".cache", "selenium")))

  module_function

  def remove_stale_chromedriver_cache(cache_root: DEFAULT_CACHE_ROOT)
    cache_root = Pathname.new(cache_root.to_s)
    chromedriver_root = cache_root.join("chromedriver")
    return unless chromedriver_root.directory?
    return if cached_chromedriver_versions(chromedriver_root).all? { |version| chromedriver_executable_present?(chromedriver_root, version) }

    FileUtils.rm_rf(chromedriver_root)
    FileUtils.rm_f(cache_root.join("se-metadata.json"))
  end

  def cached_chromedriver_versions(chromedriver_root)
    metadata_versions(chromedriver_root.dirname) | directory_versions(chromedriver_root)
  end

  def metadata_versions(cache_root)
    metadata_path = cache_root.join("se-metadata.json")
    return [] unless metadata_path.file?

    metadata = JSON.parse(metadata_path.read)
    Array(metadata["drivers"]).filter_map do |driver|
      next unless driver["driver_name"] == "chromedriver"

      driver_version = driver["driver_version"].to_s
      driver_version unless driver_version.empty?
    end
  rescue JSON::ParserError
    []
  end

  def directory_versions(chromedriver_root)
    Dir.glob(chromedriver_root.join("*", "*").to_s).filter_map do |path|
      pathname = Pathname.new(path)
      pathname.basename.to_s if pathname.directory?
    end
  end

  def chromedriver_executable_present?(chromedriver_root, version)
    cache_patterns = [
      chromedriver_root.join("*", version, "chromedriver"),
      chromedriver_root.join(version, "*", "chromedriver")
    ]

    cache_patterns.any? do |pattern|
      Dir.glob(pattern.to_s).any? { |path| File.file?(path) && File.executable?(path) }
    end
  end
end

RSpec.configure do |config|
  config.before(:suite) do
    StaleSeleniumCacheGuard.remove_stale_chromedriver_cache
  end
end
