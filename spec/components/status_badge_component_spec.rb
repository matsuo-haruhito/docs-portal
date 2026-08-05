# frozen_string_literal: true

require "rails_helper"

RSpec.describe StatusBadgeComponent, type: :component do
  describe "#initialize" do
    it "raises ArgumentError when status is nil" do
      expect { described_class.new(status: nil, label: "下書き") }
        .to raise_error(ArgumentError, /status/)
    end

    it "raises ArgumentError when status is blank" do
      expect { described_class.new(status: "  ", label: "下書き") }
        .to raise_error(ArgumentError, /status/)
    end

    it "raises ArgumentError when label is nil" do
      expect { described_class.new(status: "draft", label: nil) }
        .to raise_error(ArgumentError, /label/)
    end

    it "raises ArgumentError when label is blank" do
      expect { described_class.new(status: "draft", label: "") }
        .to raise_error(ArgumentError, /label/)
    end
  end

  describe "rendering" do
    context "with known status" do
      before { render_inline(described_class.new(status: "draft", label: "下書き")) }

      it "renders a span with status-badge class" do
        expect(page).to have_css("span.status-badge")
      end

      it "applies the correct status modifier class" do
        expect(page).to have_css("span.status-badge.status-badge--draft")
      end

      it "includes aria-label with the label text" do
        expect(page).to have_css('span.status-badge[aria-label="下書き"]')
      end

      it "displays the label text" do
        expect(page).to have_css("span.status-badge", text: "下書き")
      end

      it "does not render tooltip when not provided" do
        expect(page).not_to have_css("span.status-badge__tooltip")
      end
    end

    context "with published status" do
      before { render_inline(described_class.new(status: "published", label: "公開中")) }

      it "applies status-badge--published class" do
        expect(page).to have_css("span.status-badge.status-badge--published")
      end
    end

    context "with archived status" do
      before { render_inline(described_class.new(status: "archived", label: "アーカイブ済み")) }

      it "applies status-badge--archived class" do
        expect(page).to have_css("span.status-badge.status-badge--archived")
      end
    end

    context "with unknown status" do
      before { render_inline(described_class.new(status: "unknown_status", label: "不明")) }

      it "falls back to status-badge--unknown class" do
        expect(page).to have_css("span.status-badge.status-badge--unknown")
      end
    end

    context "with tooltip" do
      before do
        render_inline(described_class.new(
          status: "draft",
          label: "下書き",
          tooltip: "この版はまだ公開されていません。公開するには承認が必要です。"
        ))
      end

      it "renders tooltip element" do
        expect(page).to have_css("span.status-badge__tooltip")
      end

      it "makes tooltip focusable with tabindex" do
        expect(page).to have_css('span.status-badge__tooltip[tabindex="0"]')
      end

      it "includes aria-describedby linking to tooltip content" do
        tooltip_trigger = page.find("span.status-badge__tooltip")
        tooltip_id = tooltip_trigger["aria-describedby"]
        expect(tooltip_id).to be_present
        expect(page).to have_css("span##{tooltip_id}[role='tooltip']")
      end

      it "renders tooltip content text" do
        expect(page).to have_css(
          "span.status-badge__tooltip-content[role='tooltip']",
          text: "この版はまだ公開されていません。公開するには承認が必要です。"
        )
      end
    end
  end

  describe "#status_class" do
    it "returns status-badge--draft for draft" do
      component = described_class.new(status: "draft", label: "下書き")
      expect(component.status_class).to eq("status-badge--draft")
    end

    it "returns status-badge--published for published" do
      component = described_class.new(status: "published", label: "公開中")
      expect(component.status_class).to eq("status-badge--published")
    end

    it "returns status-badge--archived for archived" do
      component = described_class.new(status: "archived", label: "アーカイブ済み")
      expect(component.status_class).to eq("status-badge--archived")
    end

    it "returns status-badge--unknown for unrecognized status" do
      component = described_class.new(status: "foo", label: "不明")
      expect(component.status_class).to eq("status-badge--unknown")
    end
  end
end
