# frozen_string_literal: true

require "rails_helper"

RSpec.describe PageHeaderComponent, type: :component do
  describe "正常系レンダリング" do
    it "header 要素に page-header クラスを付与して描画する" do
      render_inline(described_class.new(title: "文書詳細"))

      expect(page).to have_css("header.page-header")
    end

    it "h1 要素でタイトルを描画する" do
      render_inline(described_class.new(title: "文書詳細"))

      expect(page).to have_css("h1.page-header__title", text: "文書詳細")
    end

    it "subtitle を指定した場合に p 要素で描画する" do
      render_inline(described_class.new(title: "文書詳細", subtitle: "案件Aの文書"))

      expect(page).to have_css("p.page-header__subtitle", text: "案件Aの文書")
    end

    it "subtitle を指定しない場合は subtitle 要素を描画しない" do
      render_inline(described_class.new(title: "文書詳細"))

      expect(page).not_to have_css("p.page-header__subtitle")
    end
  end

  describe "breadcrumbs slot" do
    it "breadcrumbs slot を描画する" do
      render_inline(described_class.new(title: "文書詳細")) do |component|
        component.with_breadcrumbs do
          '<nav class="breadcrumb-nav">パンくず</nav>'.html_safe
        end
      end

      expect(page).to have_css(".page-header__breadcrumbs nav.breadcrumb-nav")
    end

    it "breadcrumbs slot が未指定の場合は breadcrumbs 領域を描画しない" do
      render_inline(described_class.new(title: "文書詳細"))

      expect(page).not_to have_css(".page-header__breadcrumbs")
    end
  end

  describe "actions slot" do
    it "actions slot を描画する" do
      render_inline(described_class.new(title: "文書詳細")) do |component|
        component.with_action do
          '<a href="/edit">編集</a>'.html_safe
        end
        component.with_action do
          '<a href="/delete">削除</a>'.html_safe
        end
      end

      expect(page).to have_css(".page-header__actions a[href='/edit']")
      expect(page).to have_css(".page-header__actions a[href='/delete']")
    end

    it "actions が未指定の場合は actions 領域を描画しない" do
      render_inline(described_class.new(title: "文書詳細"))

      expect(page).not_to have_css(".page-header__actions")
    end
  end

  describe "必須パラメータ検証" do
    it "title が nil の場合 ArgumentError を raise する" do
      expect { described_class.new(title: nil) }.to raise_error(ArgumentError, /title/)
    end

    it "title が空文字の場合 ArgumentError を raise する" do
      expect { described_class.new(title: "") }.to raise_error(ArgumentError, /title/)
    end

    it "title が空白のみの場合 ArgumentError を raise する" do
      expect { described_class.new(title: "   ") }.to raise_error(ArgumentError, /title/)
    end
  end
end
