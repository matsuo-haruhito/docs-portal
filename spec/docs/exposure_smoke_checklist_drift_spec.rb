require "rails_helper"

RSpec.describe "exposure smoke checklist drift" do
  REPO_ROOT = Rails.root

  GUARDS = [
    {
      name: "external user exposure",
      smoke_path: "bin/external_user_exposure_smoke",
      checklist_path: "docs/社外ユーザー向け情報露出点検チェックリスト.md",
      checklist_start: "## 5. 代表ケース",
      checklist_end: "日常 smoke として同じ集合をまとめて実行する場合は"
    },
    {
      name: "operational metadata exposure",
      smoke_path: "bin/operational_metadata_exposure_smoke",
      checklist_path: "docs/運用metadata情報露出点検チェックリスト.md",
      checklist_start: "first slice で束ねる spec subset は次です。",
      checklist_end: "この subset は"
    }
  ].freeze

  SPEC_PATH_PATTERN = %r{spec/requests/[[:alnum:]_/]+_spec\.rb}

  GUARDS.each do |guard|
    it "keeps #{guard.fetch(:name)} smoke spec list aligned with its checklist" do
      smoke_specs = extract_smoke_spec_files(REPO_ROOT.join(guard.fetch(:smoke_path)))
      checklist_specs = extract_checklist_spec_files(
        REPO_ROOT.join(guard.fetch(:checklist_path)),
        start_marker: guard.fetch(:checklist_start),
        end_marker: guard.fetch(:checklist_end)
      )

      expect(checklist_specs).to eq(smoke_specs), drift_message(guard, smoke_specs, checklist_specs)
    end
  end

  it "keeps external user digest rows aligned with its smoke spec list" do
    smoke_path = REPO_ROOT.join("bin/external_user_exposure_smoke")

    expect(extract_digest_spec_files(smoke_path)).to eq(extract_smoke_spec_files(smoke_path))
  end

  it "keeps external-user and operational-metadata smoke responsibilities separate" do
    smoke_specs_by_name = GUARDS.to_h do |guard|
      [guard.fetch(:name), extract_smoke_spec_files(REPO_ROOT.join(guard.fetch(:smoke_path)))]
    end

    overlap = smoke_specs_by_name.fetch("external user exposure") &
              smoke_specs_by_name.fetch("operational metadata exposure")

    expect(overlap).to be_empty
  end

  def extract_smoke_spec_files(path)
    source = path.read
    spec_files_literal = source[/SPEC_FILES\s*=\s*\[(.*?)\]\.freeze/m, 1]
    raise "#{path.relative_path_from(REPO_ROOT)} does not define a frozen SPEC_FILES array" unless spec_files_literal

    spec_files_literal.scan(/"(#{SPEC_PATH_PATTERN.source})"/).flatten
  end

  def extract_digest_spec_files(path)
    source = path.read
    digest_rows_literal = source[/DIGEST_ROWS\s*=\s*\[(.*?)\]\.freeze/m, 1]
    raise "#{path.relative_path_from(REPO_ROOT)} does not define a frozen DIGEST_ROWS array" unless digest_rows_literal

    digest_rows_literal.scan(/spec:\s*"(#{SPEC_PATH_PATTERN.source})"/).flatten
  end

  def extract_checklist_spec_files(path, start_marker:, end_marker:)
    source = path.read
    checklist_section = source[/#{Regexp.escape(start_marker)}(.*?)#{Regexp.escape(end_marker)}/m, 1]
    raise "#{path.relative_path_from(REPO_ROOT)} is missing checklist section markers" unless checklist_section

    checklist_section.scan(/`(#{SPEC_PATH_PATTERN.source})`/).flatten
  end

  def drift_message(guard, smoke_specs, checklist_specs)
    missing_from_checklist = smoke_specs - checklist_specs
    missing_from_smoke = checklist_specs - smoke_specs

    <<~MESSAGE
      #{guard.fetch(:name)} smoke/checklist spec list drifted.
      Smoke: #{guard.fetch(:smoke_path)}
      Checklist: #{guard.fetch(:checklist_path)}
      Missing from checklist: #{missing_from_checklist.inspect}
      Missing from smoke: #{missing_from_smoke.inspect}
    MESSAGE
  end
end
