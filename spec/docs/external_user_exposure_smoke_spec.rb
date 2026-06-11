require "rails_helper"

RSpec.describe "External user exposure smoke checklist" do
  CHECKLIST_PATH = "docs/社外ユーザー向け情報露出点検チェックリスト.md"
  SCRIPT_PATH = "bin/external_user_exposure_smoke"

  def read_source(path)
    Rails.root.join(path).read
  end

  def checklist_spec_files(source)
    representative_section = source[/^## 5\. 代表ケース\n(?<section>.*?)(?=^## 6\. |\z)/m, :section]
    raise "代表ケース section was not found" unless representative_section

    representative_section.scan(/`(spec\/requests\/[^`]+_spec\.rb)`/).flatten
  end

  def script_spec_files(source)
    list_body = source[/SPEC_FILES = \[(?<body>.*?)\]\.freeze/m, :body]
    raise "SPEC_FILES list was not found" unless list_body

    list_body.scan(/"([^"]+)"/).flatten
  end

  let(:checklist_source) { read_source(CHECKLIST_PATH) }
  let(:script_source) { read_source(SCRIPT_PATH) }
  let(:checklist_files) { checklist_spec_files(checklist_source) }
  let(:script_files) { script_spec_files(script_source) }

  it "keeps the smoke script aligned with the representative checklist specs" do
    missing_from_script = checklist_files - script_files
    stale_script_entries = script_files - checklist_files

    expect(missing_from_script).to be_empty, "smoke script is missing checklist specs: #{missing_from_script.join(', ')}"
    expect(stale_script_entries).to be_empty, "smoke script has stale specs: #{stale_script_entries.join(', ')}"
  end

  it "points to existing request specs only" do
    expect(script_files).not_to be_empty
    script_files.each do |path|
      expect(Rails.root.join(path)).to exist
    end
  end

  it "documents the lightweight smoke command next to the checklist" do
    expect(checklist_source).to include("bundle exec ruby bin/external_user_exposure_smoke")
    expect(checklist_source).to include("運用 metadata 情報露出点検チェックリスト")
  end
end
