require "rails_helper"
require Rails.root.join("db/seeds/support/docusaurus_markdown_normalizer")

RSpec.describe SeedSupport::DocusaurusMarkdownNormalizer do
  def normalize(markdown, generated_id: "seed-test")
    described_class.new(markdown:, generated_id:).normalize
  end

  it "adds generated front matter when markdown has no front matter" do
    result = normalize("# Hello\n")

    expect(result).to include("id: seed-test")
    expect(result).to include("# Hello")
  end

  it "replaces existing front matter id" do
    result = normalize("---\nid: old-id\ntitle: Old\n---\n# Hello\n", generated_id: "seed-new")

    expect(result).to include("id: seed-new")
    expect(result).to include("title: Old")
    expect(result).not_to include("id: old-id")
  end

  it "rewrites local README markdown links for seed builds" do
    result = normalize("[Guide](guide/README.md) [External](https://example.com/README.md)\n")

    expect(result).to include("](guide/index.md)")
    expect(result).to include("](https://example.com/README.md)")
  end

  it "escapes MDX angle brackets outside fenced code blocks" do
    result = normalize("Use <Component> here.\n\n```ruby\nputs '<keep>'\n```\n")

    expect(result).to include("Use &lt;Component&gt; here.")
    expect(result).to include("puts '<keep>'")
  end
end
