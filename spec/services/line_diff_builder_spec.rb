require "rails_helper"

RSpec.describe LineDiffBuilder do
  it "returns added and removed lines with stable line numbers" do
    lines = described_class.new(
      ["A", "B", "C"],
      ["A", "B2", "C", "D"],
      context_lines: 1
    ).call

    expect(lines.map(&:kind)).to eq(%i[context removed added context added])
    expect(lines.map(&:old_number)).to eq([1, 2, nil, 3, nil])
    expect(lines.map(&:new_number)).to eq([1, nil, 2, 3, 4])
    expect(lines.map(&:text)).to eq(["A", "B", "B2", "C", "D"])
  end

  it "compacts distant unchanged sections with gaps" do
    lines = described_class.new(
      ["a", "same-1", "same-2", "same-3", "z"],
      ["a!", "same-1", "same-2", "same-3", "z!"],
      context_lines: 0
    ).call

    expect(lines.map(&:kind)).to eq(%i[removed added gap removed added])
    expect(lines.map(&:text)).to eq(["a", "a!", "...", "z", "z!"])
  end

  it "returns an empty list when there are no changes" do
    lines = described_class.new(["A"], ["A"]).call

    expect(lines).to eq([])
  end
end
