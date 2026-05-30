require "rails_helper"
require "tmpdir"

RSpec.describe StaleSeleniumCacheGuard do
  around do |example|
    Dir.mktmpdir do |dir|
      @cache_root = Pathname.new(dir)
      example.run
    end
  end

  it "removes chromedriver cache and metadata when the cached executable is missing" do
    chromedriver_root = @cache_root.join("chromedriver")
    FileUtils.mkdir_p(chromedriver_root.join("linux64", "149.0.7827.54"))
    @cache_root.join("se-metadata.json").write(
      {
        "drivers" => [
          {
            "driver_name" => "chromedriver",
            "driver_version" => "149.0.7827.54"
          }
        ]
      }.to_json
    )

    described_class.remove_stale_chromedriver_cache(cache_root: @cache_root)

    expect(chromedriver_root).not_to exist
    expect(@cache_root.join("se-metadata.json")).not_to exist
  end

  it "keeps chromedriver cache when the cached executable exists" do
    chromedriver_path = @cache_root.join("chromedriver", "149.0.7827.54", "linux64", "chromedriver")
    FileUtils.mkdir_p(chromedriver_path.dirname)
    FileUtils.touch(chromedriver_path)
    FileUtils.chmod(0o755, chromedriver_path)
    @cache_root.join("se-metadata.json").write(
      {
        "drivers" => [
          {
            "driver_name" => "chromedriver",
            "driver_version" => "149.0.7827.54"
          }
        ]
      }.to_json
    )

    described_class.remove_stale_chromedriver_cache(cache_root: @cache_root)

    expect(chromedriver_path).to exist
    expect(@cache_root.join("se-metadata.json")).to exist
  end

  it "does nothing when the chromedriver cache has not been created" do
    described_class.remove_stale_chromedriver_cache(cache_root: @cache_root)

    expect(@cache_root).to exist
  end
end
