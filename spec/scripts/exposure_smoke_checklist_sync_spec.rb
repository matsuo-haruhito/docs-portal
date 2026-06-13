require "pathname"

RSpec.describe "exposure smoke checklist sync" do
  ROOT = Pathname.new(__dir__).join("../..").expand_path

  SMOKE_CHECKLISTS = [
    {
      name: "external user exposure",
      script_path: "bin/external_user_exposure_smoke",
      checklist_path: "docs/社外ユーザー向け情報露出点検チェックリスト.md",
      checklist_start: "## 5. 代表ケース",
      checklist_end: "日常 smoke として同じ集合をまとめて実行する場合"
    },
    {
      name: "operational metadata exposure",
      script_path: "bin/operational_metadata_exposure_smoke",
      checklist_path: "docs/運用metadata情報露出点検チェックリスト.md",
      checklist_start: "first slice で束ねる spec subset は次です。",
      checklist_end: "この subset は"
    }
  ].freeze

  def read_repo_file(path)
    ROOT.join(path).read
  end

  def smoke_spec_files(script_source)
    match = script_source.match(/SPEC_FILES\s*=\s*\[(.*?)\]\.freeze/m)
    raise "SPEC_FILES was not found" unless match

    match[1].scan(/"(spec\/requests\/[^\"]+_spec\.rb)"/).flatten
  end

  def checklist_spec_files(markdown_source, start_marker:, end_marker:)
    start_index = markdown_source.index(start_marker)
    raise "checklist start marker was not found: #{start_marker}" unless start_index

    body = markdown_source[start_index..]
    end_index = body.index(end_marker)
    raise "checklist end marker was not found: #{end_marker}" unless end_index

    body[0...end_index].scan(/`(spec\/requests\/[^`]+_spec\.rb)`/).flatten
  end

  def drift_message(name:, script_path:, checklist_path:, smoke_files:, checklist_files:)
    missing_from_smoke = checklist_files - smoke_files
    missing_from_checklist = smoke_files - checklist_files
    return nil if missing_from_smoke.empty? && missing_from_checklist.empty?

    lines = ["#{name} smoke/checklist drift detected between #{script_path} and #{checklist_path}."]
    lines << "Missing from smoke script: #{missing_from_smoke.join(', ')}" if missing_from_smoke.any?
    lines << "Missing from checklist: #{missing_from_checklist.join(', ')}" if missing_from_checklist.any?
    lines.join("\n")
  end

  it "keeps each smoke SPEC_FILES list in sync with its checklist spec list" do
    aggregate_failures do
      SMOKE_CHECKLISTS.each do |target|
        smoke_files = smoke_spec_files(read_repo_file(target[:script_path]))
        checklist_files = checklist_spec_files(
          read_repo_file(target[:checklist_path]),
          start_marker: target[:checklist_start],
          end_marker: target[:checklist_end]
        )
        message = drift_message(
          name: target[:name],
          script_path: target[:script_path],
          checklist_path: target[:checklist_path],
          smoke_files: smoke_files,
          checklist_files: checklist_files
        )

        expect(message).to be_nil, message
        expect(smoke_files).to all(satisfy { |path| ROOT.join(path).file? }), "#{target[:name]} smoke has missing spec files"
      end
    end
  end

  it "names the affected smoke and checklist when a spec exists only in the checklist" do
    message = drift_message(
      name: "external user exposure",
      script_path: "bin/external_user_exposure_smoke",
      checklist_path: "docs/社外ユーザー向け情報露出点検チェックリスト.md",
      smoke_files: ["spec/requests/external_document_access_spec.rb"],
      checklist_files: ["spec/requests/external_document_access_spec.rb", "spec/requests/document_search_spec.rb"]
    )

    expect(message).to include("external user exposure")
    expect(message).to include("bin/external_user_exposure_smoke")
    expect(message).to include("docs/社外ユーザー向け情報露出点検チェックリスト.md")
    expect(message).to include("Missing from smoke script: spec/requests/document_search_spec.rb")
  end

  it "names the affected smoke and checklist when a spec exists only in the script" do
    message = drift_message(
      name: "operational metadata exposure",
      script_path: "bin/operational_metadata_exposure_smoke",
      checklist_path: "docs/運用metadata情報露出点検チェックリスト.md",
      smoke_files: ["spec/requests/admin_file_upload_dry_runs_spec.rb", "spec/requests/admin_webhook_deliveries_spec.rb"],
      checklist_files: ["spec/requests/admin_file_upload_dry_runs_spec.rb"]
    )

    expect(message).to include("operational metadata exposure")
    expect(message).to include("bin/operational_metadata_exposure_smoke")
    expect(message).to include("docs/運用metadata情報露出点検チェックリスト.md")
    expect(message).to include("Missing from checklist: spec/requests/admin_webhook_deliveries_spec.rb")
  end
end
