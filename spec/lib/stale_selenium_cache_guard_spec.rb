require "rails_helper"
require "tmpdir"

RSpec.describe StaleSeleniumCacheGuard do
  def write_metadata(cache_root, driver_version: "149.0.7827.54")
    cache_root.join("se-metadata.json").write(
      {
        "drivers" => [
          {
            "driver_name" => "chromedriver",
            "driver_version" => driver_version
          }
        ]
      }.to_json
    )
  end

  around do |example|
    Dir.mktmpdir do |directory|
      @cache_root = Pathname.new(directory)
      example.run
    end
  end

  it "removes Selenium metadata when it points at a missing chromedriver cache" do
    write_metadata(@cache_root)

    described_class.remove_stale_chromedriver_cache(cache_root: @cache_root)

    expect(@cache_root.join("se-metadata.json")).not_to exist
  end

  it "removes the chromedriver cache and metadata when the cached executable is missing" do
    write_metadata(@cache_root)
    @cache_root.join("chromedriver", "linux64", "149.0.7827.54").mkpath

    described_class.remove_stale_chromedriver_cache(cache_root: @cache_root)

    expect(@cache_root.join("chromedriver")).not_to exist
    expect(@cache_root.join("se-metadata.json")).not_to exist
  end

  it "keeps a chromedriver cache that has an executable for the metadata version" do
    write_metadata(@cache_root)
    chromedriver_path = @cache_root.join("chromedriver", "linux64", "149.0.7827.54", "chromedriver")
    chromedriver_path.dirname.mkpath
    chromedriver_path.write("")
    chromedriver_path.chmod(0o755)

    described_class.remove_stale_chromedriver_cache(cache_root: @cache_root)

    expect(@cache_root.join("chromedriver")).to exist
    expect(@cache_root.join("se-metadata.json")).to exist
  end
end
