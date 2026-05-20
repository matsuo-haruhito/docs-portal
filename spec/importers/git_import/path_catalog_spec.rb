require "rails_helper"
require "tmpdir"

RSpec.describe GitImport::PathCatalog do
  around do |example|
    Dir.mktmpdir("git-import-path-catalog") do |dir|
      @worktree = Pathname.new(dir)
      example.run
    end
  end

  it "detects md, markdown, and mdx files as markdown paths" do
    write_file("docs/a.md", "# A")
    write_file("docs/b.markdown", "# B")
    write_file("docs/c.mdx", "# C")
    write_file("docs/image.png", "image")

    catalog = described_class.new(worktree_path: @worktree)

    expect(catalog.markdown_paths.map { _1.relative_path_from(@worktree).to_s }).to eq([
      "docs/a.md",
      "docs/b.markdown",
      "docs/c.mdx"
    ])
  end

  it "treats md, markdown, and mdx as text markdown content" do
    catalog = described_class.new(worktree_path: @worktree)

    expect(catalog.content_type_for(Pathname("a.md"))).to eq("text/markdown")
    expect(catalog.content_type_for(Pathname("b.markdown"))).to eq("text/markdown")
    expect(catalog.content_type_for(Pathname("c.mdx"))).to eq("text/markdown")
  end

  private

  def write_file(relative_path, content)
    path = @worktree.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(content)
  end
end
