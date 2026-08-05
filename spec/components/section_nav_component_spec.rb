# frozen_string_literal: true

require "rails_helper"

RSpec.describe SectionNavComponent, type: :component do
  describe "rendering" do
    it "renders nav with role=tablist and aria-label" do
      sections = [{ id: "attributes", label: "属性" }]

      render_inline(described_class.new(sections: sections))

      expect(page).to have_css("nav.section-nav[role='tablist'][aria-label='文書詳細ナビゲーション']")
    end

    it "renders tabs with role=tab and aria-controls" do
      sections = [
        { id: "attributes", label: "属性" },
        { id: "versions", label: "版一覧" }
      ]

      render_inline(described_class.new(sections: sections))

      expect(page).to have_css("a.section-nav__tab[role='tab'][aria-controls='attributes']", text: "属性")
      expect(page).to have_css("a.section-nav__tab[role='tab'][aria-controls='versions']", text: "版一覧")
    end

    it "marks first tab as aria-selected=true and is-active" do
      sections = [
        { id: "attributes", label: "属性" },
        { id: "versions", label: "版一覧" }
      ]

      render_inline(described_class.new(sections: sections))

      first_tab = page.find("a.section-nav__tab[aria-controls='attributes']")
      expect(first_tab[:"aria-selected"]).to eq("true")
      expect(first_tab[:class]).to include("is-active")

      second_tab = page.find("a.section-nav__tab[aria-controls='versions']")
      expect(second_tab[:"aria-selected"]).to eq("false")
      expect(second_tab[:class]).not_to include("is-active")
    end

    it "limits tabs to 10 when more than 10 sections provided" do
      sections = (1..15).map { |i| { id: "section-#{i}", label: "セクション#{i}" } }

      render_inline(described_class.new(sections: sections))

      expect(page).to have_css("a.section-nav__tab", count: 10)
    end

    it "does not render when sections is empty" do
      render_inline(described_class.new(sections: []))

      expect(page).not_to have_css("nav.section-nav")
    end

    it "includes data-controller=section-nav" do
      sections = [{ id: "attributes", label: "属性" }]

      render_inline(described_class.new(sections: sections))

      expect(page).to have_css("nav.section-nav[data-controller='section-nav']")
    end
  end

  describe "#render?" do
    it "returns false when sections is empty" do
      component = described_class.new(sections: [])
      expect(component.render?).to be false
    end

    it "returns true when sections has items" do
      component = described_class.new(sections: [{ id: "test", label: "テスト" }])
      expect(component.render?).to be true
    end
  end
end
