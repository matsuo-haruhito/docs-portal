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
  EVIDENCE_GUIDE_PATH = "docs/情報露出smoke evidence運用メモ.md"

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

    it "keeps #{guard.fetch(:name)} digest rows aligned with its smoke spec list" do
      smoke_path = REPO_ROOT.join(guard.fetch(:smoke_path))

      expect(extract_digest_spec_files(smoke_path)).to eq(extract_smoke_spec_files(smoke_path))
    end
  end

  it "keeps operational metadata smoke markdown digest format out of RSpec passthrough" do
    source = REPO_ROOT.join("bin/operational_metadata_exposure_smoke").read

    expect(source).to include('argument == "--format" && argv[index + 1] == "markdown"')
    expect(source).to include('argument == "--format=markdown"')
    expect(source).to include('remaining << argument')
  end

  it "keeps external-user and operational-metadata smoke responsibilities separate" do
    smoke_specs_by_name = GUARDS.to_h do |guard|
      [guard.fetch(:name), extract_smoke_spec_files(REPO_ROOT.join(guard.fetch(:smoke_path)))]
    end

    overlap = smoke_specs_by_name.fetch("external user exposure") &
              smoke_specs_by_name.fetch("operational metadata exposure")

    expect(overlap).to be_empty
  end

  it "keeps operational metadata evidence guidance discoverable without raw-value handoff" do
    docs_by_path = {
      "README.md" => REPO_ROOT.join("README.md").read,
      "docs/README.md" => REPO_ROOT.join("docs/README.md").read,
      "docs/運用metadata情報露出点検チェックリスト.md" => REPO_ROOT.join("docs/運用metadata情報露出点検チェックリスト.md").read,
      EVIDENCE_GUIDE_PATH => REPO_ROOT.join(EVIDENCE_GUIDE_PATH).read
    }

    require_representative_text(
      docs_by_path.fetch("README.md"),
      "README.md",
      [
        "bin/external_user_exposure_smoke",
        "bin/operational_metadata_exposure_smoke",
        "PR / release evidence 用の短い digest",
        "raw values や詳細 payload は貼らない"
      ]
    )

    require_representative_text(
      docs_by_path.fetch("docs/README.md"),
      "docs/README.md",
      [
        "運用 metadata 情報露出点検チェックリスト",
        "情報露出 smoke evidence 運用メモ",
        "external user exposure smoke と operational metadata exposure smoke の PR / release evidence での使い分け",
        "raw value 非転記境界"
      ]
    )

    require_representative_text(
      docs_by_path.fetch("docs/運用metadata情報露出点検チェックリスト.md"),
      "docs/運用metadata情報露出点検チェックリスト.md",
      [
        "Markdown digest は smoke 名、実行時刻、RSpec 結果",
        "raw path、raw payload、token-like value、PII-like value",
        "provider payload は digest に貼らない",
        "完全な失敗内容は対象 spec / 画面 / runbook へ戻って確認します"
      ]
    )

    require_representative_text(
      docs_by_path.fetch(EVIDENCE_GUIDE_PATH),
      EVIDENCE_GUIDE_PATH,
      [
        "PR / release evidence template",
        "digest 本文に出ない raw value を手で追記しません",
        "失敗時の詳細 payload や raw value を足して補強しないでください",
        "external_user_exposure_smoke は社外ユーザーの閲覧権限境界",
        "operational_metadata_exposure_smoke は admin / integration metadata の表示境界"
      ]
    )
  end

  it "keeps PR and release evidence guidance bounded to digest summaries" do
    guide = REPO_ROOT.join(EVIDENCE_GUIDE_PATH).read
    external_smoke = REPO_ROOT.join("bin/external_user_exposure_smoke").read
    operational_smoke = REPO_ROOT.join("bin/operational_metadata_exposure_smoke").read

    aggregate = [guide, external_smoke, operational_smoke].join("\n")

    expect(guide).to include("PR / release evidence template")
    expect(guide).to include("bin/external_user_exposure_smoke --format markdown")
    expect(guide).to include("bin/operational_metadata_exposure_smoke --format markdown")
    expect(guide).to include("対象 spec / surface / runbook へ戻って確認する")
    expect(guide).to include("docs/社外ユーザー向け情報露出点検チェックリスト.md")
    expect(guide).to include("docs/運用metadata情報露出点検チェックリスト.md")

    [
      "raw payload",
      "raw response",
      "token-like value",
      "provider payload",
      "PII-like value"
    ].each do |forbidden_detail|
      expect(aggregate).to include(forbidden_detail)
    end
  end

  it "keeps smoke markdown digests self-contained for reviewer handoff" do
    external_smoke = REPO_ROOT.join("bin/external_user_exposure_smoke").read
    operational_smoke = REPO_ROOT.join("bin/operational_metadata_exposure_smoke").read

    expect(external_smoke).to include('NEXT_CHECKLIST = "docs/社外ユーザー向け情報露出点検チェックリスト.md"')
    expect(external_smoke).to include('- next checklist: `#{NEXT_CHECKLIST}`')
    expect(external_smoke).to include('- failure handoff: #{FAILURE_HANDOFF}')
    expect(external_smoke).to include("HTML / JSON / ZIP payload、raw response、token-like value")
    expect(external_smoke).to include("権限外文書名は貼らない")

    expect(operational_smoke).to include('NEXT_CHECKLIST = "docs/運用metadata情報露出点検チェックリスト.md"')
    expect(operational_smoke).to include('- next checklist: `#{NEXT_CHECKLIST}`')
    expect(operational_smoke).to include('- failure handoff: #{FAILURE_HANDOFF}')
    expect(operational_smoke).to include("raw path、raw payload、token-like value")
    expect(operational_smoke).to include("provider payload は貼らない")
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

  def require_representative_text(source, relative_path, expected_texts)
    expected_texts.each do |expected_text|
      next if source.include?(expected_text)

      raise RSpec::Expectations::ExpectationNotMetError,
            "#{relative_path}: missing operational metadata evidence boundary text: #{expected_text.inspect}"
    end
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
