# frozen_string_literal: true

require "rails_helper"

RSpec.describe HelpTooltipComponent, type: :component do
  describe "#initialize" do
    it "raises ArgumentError when description is nil" do
      expect { described_class.new(description: nil) }
        .to raise_error(ArgumentError, /description/)
    end

    it "raises ArgumentError when description is blank" do
      expect { described_class.new(description: "") }
        .to raise_error(ArgumentError, /description/)
    end
  end

  describe "rendering" do
    let(:component) { described_class.new(description: "質問は外部ユーザーにも見える投稿です") }

    before { render_inline(component) }

    it "renders a span with help-tooltip class" do
      expect(page).to have_css("span.help-tooltip")
    end

    it "includes tabindex=0 for keyboard accessibility" do
      expect(page).to have_css('span.help-tooltip[tabindex="0"]')
    end

    it "includes aria-label with description text" do
      expect(page).to have_css('span.help-tooltip[aria-label="質問は外部ユーザーにも見える投稿です"]')
    end

    it "includes aria-describedby linking to tooltip content" do
      tooltip_id = page.find("span.help-tooltip")["aria-describedby"]
      expect(page).to have_css("span##{tooltip_id}[role='tooltip']")
    end

    it "renders a Bootstrap icon inside the aria-hidden trigger" do
      expect(page).to have_css('span.help-tooltip__trigger[aria-hidden="true"] i.bi.bi-question-circle')
    end

    it "renders tooltip content with description" do
      expect(page).to have_css("span.help-tooltip__content[role='tooltip']", text: "質問は外部ユーザーにも見える投稿です")
    end

    it "truncates description exceeding 200 characters" do
      long_desc = "い" * 250
      render_inline(described_class.new(description: long_desc))
      content = page.find("span.help-tooltip__content").text
      expect(content.length).to be <= 200
    end
  end
end
