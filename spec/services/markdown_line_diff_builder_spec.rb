require "rails_helper"

RSpec.describe MarkdownLineDiffBuilder do
  LineFile = Struct.new(:file_name, :file_size, :absolute_path, keyword_init: true)

  it "includes mdx files in line diffs" do
    previous_file = temp_line_file("docs/guide.mdx", "# Guide\nold\n")
    current_file = temp_line_file("docs/guide.mdx", "# Guide\nnew\n")
    row = {
      file: current_file,
      previous_file: previous_file,
      path: "docs/guide.mdx",
      status: :changed
    }

    diff = described_class.new(current_version: nil, previous_version: double("previous"), file_rows: [row]).call.first

    expect(diff.path).to eq("docs/guide.mdx")
    expect(diff.lines.map(&:kind)).to include(:removed, :added)
  ensure
    previous_file&.absolute_path&.delete if previous_file&.absolute_path&.exist?
    current_file&.absolute_path&.delete if current_file&.absolute_path&.exist?
  end

  private

  def temp_line_file(file_name, content)
    tempfile = Tempfile.new(["markdown-line-diff", File.extname(file_name)])
    tempfile.write(content)
    tempfile.rewind
    path = Pathname.new(tempfile.path)
    tempfile.close

    LineFile.new(file_name: file_name, file_size: path.size, absolute_path: path)
  end
end
