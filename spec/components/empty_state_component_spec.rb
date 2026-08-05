# frozen_string_literal: true

require "rails_helper"

RSpec.describe EmptyStateComponent, type: :component do
  describe "#initialize" do
    it "raises ArgumentError when heading is nil" do
      expect { described_class.new(heading: nil, description: "説明文") }
        .to raise_error(ArgumentError, /heading/)
    end

    it "raises ArgumentError when heading is blank" do
      expect { described_class.new(heading: "  ", description: "説明文") }
        .to raise_error(ArgumentError, /heading/)
    end

    it "raises ArgumentError when description is nil" do
      expect { described_class.new(heading: "見出し", description: nil) }
        .to raise_error(ArgumentError, /description/)
    end

    it "raises ArgumentError when description is blank" do
      expect { described_class.new(heading: "見出し", description: "") }
        .to raise_error(ArgumentError, /description/)
    end
  end

  describe "rendering" do
    it "renders heading and description" do
      render_inline(described_class.new(heading: "関連文書がありません", description: "この文書に関連する文書はまだ登録されていません。"))

      expect(page).to have_css("div.empty-state")
      expect(page).to have_css("h3.empty-state__heading", text: "関連文書がありません")
      expect(page).to have_css("p.empty-state__description", text: "この文書に関連する文書はまだ登録されていません。")
    end

    it "renders actions slot when provided" do
      render_inline(described_class.new(heading: "見出し", description: "説明")) do |component|
        component.with_action do
          '<a href="/documents">文書一覧へ</a>'.html_safe
        end
      end

      expect(page).to have_css(".empty-state__actions a[href='/documents']")
    end

    it "does not render actions div when no actions provided" do
      render_inline(described_class.new(heading: "見出し", description: "説明"))

      expect(page).not_to have_css(".empty-state__actions")
    end
  end
end
