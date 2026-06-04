require "rails_helper"

RSpec.describe DocumentFileArchivePreview do
  let(:project) { create(:project) }
  let(:document) { create(:document, project:) }
  let(:version) { create(:document_version, document:) }

  def storage_path(storage_key)
    path = DocumentFile.verified_storage_path(storage_key)
    FileUtils.mkdir_p(path.dirname)
    path
  end

  def write_zip(storage_key, entries)
    path = storage_path(storage_key)
    FileUtils.rm_f(path)

    Zip::File.open(path, create: true) do |zip_file|
      entries.each do |name, content|
        if content == :directory
          zip_file.mkdir(name)
        else
          zip_file.get_output_stream(name) { |io| io.write(content) }
        end
      end
    end
  end

  def write_storage_file(storage_key, content)
    File.binwrite(storage_path(storage_key), content)
  end

  it "lists zip entries" do
    storage_key = "spec/archive-preview/items.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "image.png" => "png"
    })
    file = create(:document_file, document_version: version, file_name: "items.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    expect(preview).not_to be_error
    expect(preview).not_to be_truncated
    expect(preview.entries.map(&:name)).to include("docs/readme.txt", "image.png")
    readme = preview.entries.find { _1.name == "docs/readme.txt" }
    expect(readme).not_to be_directory
    expect(readme.size).to eq(5)
  end

  it "exposes entry parent directories" do
    storage_key = "spec/archive-preview/parent-directory.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "index.html" => "html"
    })
    file = create(:document_file, document_version: version, file_name: "parent-directory.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    parents = preview.entries.index_by(&:name).transform_values(&:parent_directory)
    expect(parents["docs/"]).to eq("/")
    expect(parents["docs/readme.txt"]).to eq("docs/")
    expect(parents["index.html"]).to eq("/")
  end

  it "marks safe and unsafe entry paths" do
    storage_key = "spec/archive-preview/safe-paths.zip"
    write_zip(storage_key, {
      "docs/readme.txt" => "hello",
      "../outside.txt" => "bad"
    })
    file = create(:document_file, document_version: version, file_name: "safe-paths.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    safety = preview.entries.index_by(&:name).transform_values(&:safe_path?)
    expect(safety["docs/readme.txt"]).to eq(true)
    expect(safety["../outside.txt"]).to eq(false)
  end

  it "exposes entry action availability" do
    storage_key = "spec/archive-preview/actionable.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "../outside.txt" => "bad"
    })
    file = create(:document_file, document_version: version, file_name: "actionable.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    entries = preview.entries.index_by(&:name)
    expect(entries["docs/readme.txt"]).to be_actionable
    expect(entries["docs/readme.txt"].action_unavailable_reason).to be_nil
    expect(entries["docs/"]).not_to be_actionable
    expect(entries["docs/"].action_unavailable_reason).to eq("directory entry は操作対象外です")
    expect(entries["../outside.txt"]).not_to be_actionable
    expect(entries["../outside.txt"].action_unavailable_reason).to eq("unsafe path のため操作できません")
    expect(preview.actionable_entries.map(&:name)).to contain_exactly("docs/readme.txt")
  end

  it "classifies preview and download action candidates" do
    storage_key = "spec/archive-preview/action-candidates.zip"
    write_zip(storage_key, {
      "docs/readme.txt" => "hello",
      "data/items.csv" => "id,name\n1,A",
      "images/logo.png" => "png",
      "../outside.txt" => "bad"
    })
    file = create(:document_file, document_version: version, file_name: "action-candidates.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    entries = preview.entries.index_by(&:name)
    expect(entries["docs/readme.txt"]).to be_text_preview_candidate
    expect(entries["data/items.csv"]).to be_text_preview_candidate
    expect(entries["images/logo.png"]).not_to be_text_preview_candidate
    expect(entries["images/logo.png"]).to be_download_candidate
    expect(entries["../outside.txt"]).not_to be_download_candidate
    expect(preview.text_preview_candidate_entries.map(&:name)).to contain_exactly("docs/readme.txt", "data/items.csv")
    expect(preview.download_candidate_entries.map(&:name)).to contain_exactly("docs/readme.txt", "data/items.csv", "images/logo.png")
  end

  it "summarizes zip entries" do
    storage_key = "spec/archive-preview/summary.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "image.png" => "png"
    })
    file = create(:document_file, document_version: version, file_name: "summary.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.file_entries.map(&:name)).to contain_exactly("docs/readme.txt", "image.png")
    expect(preview.file_count).to eq(2)
    expect(preview.folder_count).to eq(1)
    expect(preview.total_file_size).to eq(8)
  end

  it "summarizes entries by directory" do
    storage_key = "spec/archive-preview/directory-summary.zip"
    write_zip(storage_key, {
      "docs/" => :directory,
      "docs/readme.txt" => "hello",
      "docs/images/" => :directory,
      "docs/images/logo.png" => "png",
      "index.html" => "html"
    })
    file = create(:document_file, document_version: version, file_name: "directory-summary.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    summaries = preview.directory_summaries.index_by(&:path)
    expect(summaries.keys).to contain_exactly("/", "docs/", "docs/images/")
    expect(summaries["/"].file_count).to eq(1)
    expect(summaries["/"].folder_count).to eq(1)
    expect(summaries["/"].total_file_size).to eq(4)
    expect(summaries["docs/"].file_count).to eq(1)
    expect(summaries["docs/"].folder_count).to eq(1)
    expect(summaries["docs/"].total_file_size).to eq(5)
    expect(summaries["docs/images/"].file_count).to eq(1)
    expect(summaries["docs/images/"].folder_count).to eq(0)
    expect(summaries["docs/images/"].total_file_size).to eq(3)
  end

  it "truncates entries over the limit and summarizes only visible entries" do
    storage_key = "spec/archive-preview/large.zip"
    write_zip(storage_key, {
      "docs/one.txt" => "1",
      "docs/two.txt" => "22",
      "docs/hidden.txt" => "333",
      "hidden/" => :directory
    })
    file = create(:document_file, document_version: version, file_name: "large.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:, limit: 2).call

    expect(preview).to be_truncated
    expect(preview.limit).to eq(2)
    expect(preview.entries.map(&:name)).to contain_exactly("docs/one.txt", "docs/two.txt")
    expect(preview.entries.map(&:name)).not_to include("docs/hidden.txt", "hidden/")
    expect(preview.file_count).to eq(2)
    expect(preview.folder_count).to eq(0)
    expect(preview.total_file_size).to eq(3)
    expect(preview.text_preview_candidate_entries.map(&:name)).to contain_exactly("docs/one.txt", "docs/two.txt")
    expect(preview.download_candidate_entries.map(&:name)).to contain_exactly("docs/one.txt", "docs/two.txt")

    summaries = preview.directory_summaries.index_by(&:path)
    expect(summaries.keys).to contain_exactly("docs/")
    expect(summaries["docs/"].file_count).to eq(2)
    expect(summaries["docs/"].folder_count).to eq(0)
    expect(summaries["docs/"].total_file_size).to eq(3)
  end

  it "searches matching paths beyond the default visible limit" do
    storage_key = "spec/archive-preview/search-large.zip"
    write_zip(storage_key, {
      "docs/one.txt" => "1",
      "docs/two.txt" => "2",
      "deep/target.txt" => "target",
      "deep/nested.zip" => "zip",
      "../target-secret.txt" => "unsafe"
    })
    file = create(:document_file, document_version: version, file_name: "search-large.zip", content_type: "application/zip", storage_key:)

    preview_without_query = described_class.new(file:, limit: 2).call
    preview_with_query = described_class.new(file:, limit: 2, path_query: "target").call

    expect(preview_without_query.entries.map(&:name)).to contain_exactly("docs/one.txt", "docs/two.txt")
    expect(preview_without_query.entries.map(&:name)).not_to include("deep/target.txt")
    expect(preview_with_query.entries.map(&:name)).to contain_exactly("deep/target.txt", "../target-secret.txt")
    expect(preview_with_query.entries.find { _1.name == "deep/target.txt" }).to be_text_preview_candidate
    expect(preview_with_query.entries.find { _1.name == "../target-secret.txt" }).not_to be_download_candidate
  end

  it "keeps nested archive entries unavailable when path search finds them" do
    storage_key = "spec/archive-preview/search-nested.zip"
    write_zip(storage_key, {
      "docs/one.txt" => "1",
      "deep/nested.zip" => "zip"
    })
    file = create(:document_file, document_version: version, file_name: "search-nested.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:, limit: 1, path_query: "nested").call

    expect(preview.entries.size).to eq(1)
    nested_entry = preview.entries.first
    expect(nested_entry.name).to eq("deep/nested.zip")
    expect(nested_entry).not_to be_download_candidate
    expect(nested_entry.action_unavailable_reason).to eq("nested archive entry はdownload対象外です")
  end

  it "returns an error result for broken zip" do
    storage_key = "spec/archive-preview/broken.zip"
    write_storage_file(storage_key, "not a zip")
    file = create(:document_file, document_version: version, file_name: "broken.zip", content_type: "application/zip", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.entries).to eq([])
    expect(preview).to be_error
    expect(preview.error).to be_present
  end

  it "returns an error result for unsupported archive format" do
    storage_key = "spec/archive-preview/items.tar"
    write_storage_file(storage_key, "tar")
    file = create(:document_file, document_version: version, file_name: "items.tar", content_type: "application/x-tar", storage_key:)

    preview = described_class.new(file:).call

    expect(preview.entries).to eq([])
    expect(preview).to be_error
    expect(preview.error).to include("未対応")
  end
end
