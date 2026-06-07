require "rails_helper"

RSpec.describe "Admin API specification source rows", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:build_root) { Rails.root.join("docusaurus", "build") }
  let(:primary_source_pages) { Admin::ApiSpecificationPage::PRIMARY_SOURCE_PAGES }

  before do
    @api_specification_site_fixture_paths = []
    @api_specification_source_mtimes = {}
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)
  end

  after do
    cleanup_primary_source_site_fixtures
    restore_api_specification_source_mtimes
  end

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
    expect(page_text).to include("行別Freshness cueはSourceと生成HTMLの更新時刻だけを比べ")

    source_rows = parsed_html.css("section.card li")
    primary_source_pages.each do |source_page|
      row = source_rows.find { |node| node.text.include?(source_page.label) }
      expect(row).to be_present
      row_text = row.text.gsub(/[[:space:]]+/, " ").strip
      expect(row_text).to include("編集元Markdown: #{source_page.source_path}")
      expect(row_text).to include("HTML確認先（build後）: #{source_page.site_path}")
      expect(row_text).to include("Freshness:")
      expect(row_text).to include("Source更新:")
      expect(row_text).to include("HTML更新:")

      html_link = row.css("a[href]").find { |link| link.text.squish == source_page.site_path }
      expect(html_link).to be_present
      expect(html_link["href"]).to eq(site_admin_api_specification_path(site_path: source_page.site_path))
    end
  end

  it "shows row-level freshness cues for current, stale, and missing primary sources" do
    current_source_page = primary_source_pages.second
    stale_source_page = primary_source_pages.third
    missing_source_page = Admin::ApiSpecificationPage::PrimarySourcePage.new(
      label: "Missing source fixture",
      site_path: "missing-source-fixture",
      source_path: "docs-src/missing-source-fixture.md"
    )
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:primary_source_pages).and_return(
      [current_source_page, stale_source_page, missing_source_page]
    )
    write_primary_source_site_fixture(current_source_page)
    write_primary_source_site_fixture(stale_source_page)

    current_source_path = Rails.root.join(current_source_page.source_path)
    stale_source_path = Rails.root.join(stale_source_page.source_path)
    current_html_path = build_root.join(current_source_page.site_path, "index.html")
    stale_html_path = build_root.join(stale_source_page.site_path, "index.html")
    current_time = Time.zone.local(2026, 1, 1, 10, 0, 0).to_time
    stale_html_time = Time.zone.local(2026, 1, 1, 9, 0, 0).to_time
    stale_source_time = Time.zone.local(2026, 1, 1, 11, 0, 0).to_time

    touch_api_specification_source_path(current_source_path, time: current_time)
    File.utime(current_time + 1.hour, current_time + 1.hour, current_html_path)
    touch_api_specification_source_path(stale_source_path, time: stale_source_time)
    File.utime(stale_html_time, stale_html_time, stale_html_path)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("HTML追従済み")
    expect(page_text).to include("Source と生成HTMLの更新時刻に大きな差はありません。")
    expect(page_text).to include("Source更新あり")
    expect(page_text).to include("Source がHTMLより新しい可能性があります。")
    expect(page_text).to include("Source missing")
    expect(page_text).to include("Source file が見つかりません。")
    expect(page_text).to include("Missing source fixture")
  end

  def write_primary_source_site_fixture(source_page)
    path = build_root.join(source_page.site_path, "index.html")
    FileUtils.mkdir_p(path.dirname)
    File.write(path, "<html><body>#{source_page.label}</body></html>")
    @api_specification_site_fixture_paths << path
  end

  def touch_api_specification_source_path(path, time:)
    @api_specification_source_mtimes[path.to_s] ||= { atime: path.atime, mtime: path.mtime }
    File.utime(time, time, path)
  end

  def cleanup_primary_source_site_fixtures
    @api_specification_site_fixture_paths.reverse_each do |path|
      FileUtils.rm_f(path)
      FileUtils.rmdir(path.dirname) if path.dirname.exist? && path.dirname.children.empty?
    end
  end

  def restore_api_specification_source_mtimes
    @api_specification_source_mtimes.each do |path, timestamps|
      File.utime(timestamps[:atime], timestamps[:mtime], path) if File.exist?(path)
    end
  end
end
