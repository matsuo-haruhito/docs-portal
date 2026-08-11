# frozen_string_literal: true

require "rails_helper"

RSpec.describe InfoTooltipComponent, type: :component do
  describe "#initialize" do
    it "raises ArgumentError when label is nil" do
      expect { described_class.new(label: nil, description: "説明文") }
        .to raise_error(ArgumentError, /label/)
    end

    it "raises ArgumentError when label is blank" do
      expect { described_class.new(label: "  ", description: "説明文") }
        .to raise_error(ArgumentError, /label/)
    end

    it "raises ArgumentError when description is nil" do
      expect { described_class.new(label: "カテゴリ", description: nil) }
        .to raise_error(ArgumentError, /description/)
    end

    it "raises ArgumentError when description is blank" do
      expect { described_class.new(label: "カテゴリ", description: "") }
        .to raise_error(ArgumentError, /description/)
    end
  end

  describe "rendering" do
    let(:component) { described_class.new(label: "カテゴリ", description: "文書の分類を示す") }

    before { render_inline(component) }

    it "renders a span with info-tooltip class" do
      expect(page).to have_css("span.info-tooltip")
    end

    it "includes tabindex=0 for keyboard accessibility" do
      expect(page).to have_css('span.info-tooltip[tabindex="0"]')
    end

    it "includes aria-label with description text" do
      expect(page).to have_css('span.info-tooltip[aria-label="文書の分類を示す"]')
    end

    it "includes aria-describedby linking to tooltip content" do
      tooltip_id = page.find("span.info-tooltip")["aria-describedby"]
      expect(page).to have_css("span##{tooltip_id}[role='tooltip']")
    end

    it "renders a Bootstrap icon inside the aria-hidden trigger" do
      expect(page).to have_css('span.info-tooltip__trigger[aria-hidden="true"] i.bi.bi-info-circle')
    end

    it "renders tooltip content with description" do
      expect(page).to have_css("span.info-tooltip__content[role='tooltip']", text: "文書の分類を示す")
    end

    it "truncates description exceeding 200 characters" do
      long_desc = "あ" * 250
      render_inline(described_class.new(label: "テスト", description: long_desc))
      content = page.find("span.info-tooltip__content").text
      expect(content.length).to be <= 200
    end
  end
end
