require "rails_helper"

RSpec.describe "Admin API specification source rows", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:primary_source_pages) { Admin::ApiSpecificationPage::PRIMARY_SOURCE_PAGES }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  it "distinguishes the editable Markdown source from the built HTML target" do
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示状態はAPI仕様ページ全体のbuild結果です。個別ページは、編集元Markdownを直してからDocusaurus build後の確認HTMLを開いて確認してください。")
    expect(page_text).to include("Source path はリポジトリ内の編集元Markdownです。確認HTMLは build 後に生成される admin-only の表示先です。")

    source_rows = parsed_html.css("section.card li")
    primary_source_pages.each do |source_page|
      row = source_rows.find { |node| node.text.include?(source_page.label) }
      expect(row).to be_present
      expect(row.text.gsub(/[[:space:]]+/, " ").strip).to include("編集元Markdown: #{source_page.source_path}")
      expect(row.text.gsub(/[[:space:]]+/, " ").strip).to include("確認HTML（build後）: #{source_page.site_path}")

      html_link = row.css("a[href]").find { |link| link.text.squish == source_page.site_path }
      expect(html_link).to be_present
      expect(html_link["href"]).to eq(site_admin_api_specification_path(site_path: source_page.site_path))
    end
  end
end
