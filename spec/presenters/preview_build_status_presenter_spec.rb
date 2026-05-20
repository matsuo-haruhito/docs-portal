require "rails_helper"

RSpec.describe PreviewBuildStatusPresenter do
  let(:version) { create(:document_version) }

  it "presents queued preview build status" do
    version.mark_preview_build_queued!

    presenter = described_class.new(version)

    expect(presenter.label).to eq("待機中")
    expect(presenter.message).to eq("Docusaurusプレビュー生成を待機しています。")
    expect(presenter.badge_class).to eq("warning")
    expect(presenter).to be_active
    expect(presenter).not_to be_failed
    expect(presenter.detail_lines.join("\n")).to include("試行:")
  end

  it "presents running preview build status" do
    version.mark_preview_build_running!

    presenter = described_class.new(version)

    expect(presenter.label).to eq("生成中")
    expect(presenter.badge_class).to eq("warning")
    expect(presenter).to be_active
  end

  it "presents succeeded preview build status" do
    version.mark_preview_build_succeeded!

    presenter = described_class.new(version)

    expect(presenter.label).to eq("成功")
    expect(presenter.badge_class).to eq("success")
    expect(presenter).to be_succeeded
    expect(presenter.detail_lines.join("\n")).to include("完了:")
  end

  it "presents failed preview build status with error detail" do
    version.mark_preview_build_failed!("renderer failed")

    presenter = described_class.new(version)

    expect(presenter.label).to eq("失敗")
    expect(presenter.message).to eq("Docusaurusプレビュー生成に失敗しました。")
    expect(presenter.badge_class).to eq("danger")
    expect(presenter).to be_failed
    expect(presenter.detail_lines).to include("エラー: renderer failed")
  end

  it "presents not requested preview build status" do
    presenter = described_class.new(version)

    expect(presenter.label).to eq("未要求")
    expect(presenter.badge_class).to eq("secondary")
    expect(presenter).not_to be_active
  end
end
