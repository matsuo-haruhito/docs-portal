# frozen_string_literal: true

require "rails_helper"

RSpec.describe BreadcrumbComponent, type: :component do
  describe "正常系レンダリング" do
    it "nav 要素に aria-label='パンくず' を付与する" do
      items = [
        { label: "案件A", url: "/projects/a/documents" },
        { label: "文書B", url: nil }
      ]

      render_inline(described_class.new(items: items))

      expect(page).to have_css("nav.breadcrumb-nav[aria-label='パンくず']")
    end

    it "ol 要素で順序付きリストを描画する" do
      items = [
        { label: "案件A", url: "/projects/a/documents" },
        { label: "文書B", url: nil }
      ]

      render_inline(described_class.new(items: items))

      expect(page).to have_css("ol.breadcrumb-nav__list")
    end

    it "中間アイテムをリンクとして描画する" do
      items = [
        { label: "案件A", url: "/projects/a/documents" },
        { label: "文書B", url: "/projects/a/documents/b" },
        { label: "v1.0", url: nil }
      ]

      render_inline(described_class.new(items: items))

      expect(page).to have_css("li.breadcrumb-nav__item a[href='/projects/a/documents']", text: "案件A")
      expect(page).to have_css("li.breadcrumb-nav__item a[href='/projects/a/documents/b']", text: "文書B")
    end

    it "最終アイテムに aria-current='page' を付与し、リンクなしで描画する" do
      items = [
        { label: "案件A", url: "/projects/a/documents" },
        { label: "文書B", url: nil }
      ]

      render_inline(described_class.new(items: items))

      last_item = page.find("li.breadcrumb-nav__item[aria-current='page']")
      expect(last_item).to have_css("span", text: "文書B")
      expect(last_item).not_to have_css("a")
    end
  end

  describe "ラベル切り詰め" do
    it "200文字超のラベルを truncate し、title 属性にフルテキストを設定する" do
      long_label = "あ" * 250
      items = [
        { label: long_label, url: nil }
      ]

      render_inline(described_class.new(items: items))

      span = page.find("li[aria-current='page'] span")
      expect(span[:title]).to eq(long_label)
      expect(span.text.length).to be <= 200
    end

    it "200文字以下のラベルには title 属性を設定しない" do
      items = [
        { label: "短いラベル", url: nil }
      ]

      render_inline(described_class.new(items: items))

      span = page.find("li[aria-current='page'] span")
      expect(span[:title]).to be_nil
    end

    it "リンクアイテムでも200文字超は truncate + title を付与する" do
      long_label = "い" * 250
      items = [
        { label: long_label, url: "/some/path" },
        { label: "現在ページ", url: nil }
      ]

      render_inline(described_class.new(items: items))

      link = page.find("a.breadcrumb-nav__link")
      expect(link[:title]).to eq(long_label)
      expect(link.text.length).to be <= 200
    end
  end

  describe "必須パラメータ検証" do
    it "items が nil の場合 ArgumentError を raise する" do
      expect { described_class.new(items: nil) }.to raise_error(ArgumentError)
    end

    it "items が空配列の場合 ArgumentError を raise する" do
      expect { described_class.new(items: []) }.to raise_error(ArgumentError)
    end
  end

  describe "1件のみのパンくず" do
    it "1件でも正常に描画する（最終アイテムとして扱う）" do
      items = [{ label: "現在ページ", url: nil }]

      render_inline(described_class.new(items: items))

      expect(page).to have_css("li.breadcrumb-nav__item[aria-current='page']", text: "現在ページ")
    end
  end
end
