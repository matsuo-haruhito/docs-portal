# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require_relative "../../script/check_docs_links"

RSpec.describe DocsLinkChecker do
  def write_file(root, path, content = "")
    full_path = File.join(root, path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  it "keeps the README entrypoint links valid" do
    checker = described_class.new(root: File.expand_path("../..", __dir__))

    expect(checker.broken_links).to be_empty
  end

  it "resolves encoded paths, spaces, and fragment-bearing relative links" do
    Dir.mktmpdir do |root|
      write_file(root, "README.md", <<~MARKDOWN)
        [encoded](./docs/%E6%A8%99%E6%BA%96%20seed.md#section)
        [space](./Product%20Profile.md)
        [external](https://example.com/docs)
        [page anchor](#local)
        [html mock](./docs/ui-mocks/sample.html)
      MARKDOWN
      write_file(root, "docs/README.md", "[relative](./nested/guide.md)")
      write_file(root, "docs/標準 seed.md")
      write_file(root, "Product Profile.md")
      write_file(root, "docs/nested/guide.md")

      checker = described_class.new(root: root)

      expect(checker.broken_links).to be_empty
    end
  end

  it "reports the source file, raw href, and resolved path for missing links" do
    Dir.mktmpdir do |root|
      write_file(root, "README.md", "[missing](./docs/missing.md)")
      write_file(root, "docs/README.md", "")

      checker = described_class.new(root: root)

      expect(checker.broken_links).to contain_exactly(
        have_attributes(
          source: "README.md",
          href: "./docs/missing.md",
          resolved_path: "docs/missing.md"
        )
      )
    end
  end
end
