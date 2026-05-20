require "rails_helper"

RSpec.describe DocumentHistoryStatusPresenter do
  it "returns labels and messages for current supported statuses" do
    expect(described_class.new(status: :canonical).label).to eq("現在の場所")
    expect(described_class.new(status: :moved).label).to eq("移動済み")
    expect(described_class.new(status: :missing).label).to eq("未解決")
    expect(described_class.new(status: :archived).label).to eq("アーカイブ済み")
    expect(described_class.new(status: :deleted).label).to eq("削除済み")
  end

  it "formats requested to canonical details" do
    presenter = described_class.new(status: :moved, requested_value: "old/path", canonical_value: "current/path")

    expect(presenter).to be_moved
    expect(presenter.detail).to eq("old/path -> current/path")
    expect(presenter.message).to eq("旧URLから現在の文書位置へ移動しました。")
  end

  it "treats missing, archived, and deleted as warnings" do
    expect(described_class.new(status: :missing)).to be_warning
    expect(described_class.new(status: :archived)).to be_warning
    expect(described_class.new(status: :deleted)).to be_warning
    expect(described_class.new(status: :moved)).not_to be_warning
  end
end
