require "rails_helper"

RSpec.describe "Document zip option copy", type: :request do
  let(:user) { create(:user, :internal) }
  let(:project) { create(:project, code: "ZIPUI", name: "Zip UI Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def create_downloadable_document
    document = create(:document, project:, title: "Zip Target", slug: "zip-target")
    version = create(:document_version, document:, version_label: "v1.0.0", source_relative_path: "guides/zip-target/README.md")
    document.update!(latest_version: version)
    document
  end

  it "shows zip option guidance while keeping the existing option controls in the same form" do
    create_downloadable_document

    sign_in_as(user)

    get project_documents_path(project)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("PDFだけ出力を選ぶと、Markdown原本や添付ファイルの追加指定よりもPDFのみの出力を優先します。")
    expect(page_text).to include("ZIP内パスの選択はPDFの配置にも適用されます。")
    expect(page_text).to include("ZIP対象: 検索結果全体 1件 / このページ 1件")

    zip_form = parsed_html.at_css("form[action='#{project_document_zip_path(project)}']")
    expect(zip_form).to be_present

    aggregate_failures do
      expect(zip_form.at_css('select[name="zip_path_mode"] option[value="document_title"]')&.text).to include("文書名準拠")
      expect(zip_form.at_css('select[name="zip_path_mode"] option[value="source_path"]')&.text).to include("元パス準拠")
      expect(zip_form.at_css('input[name="include_markdown_sources"][type="checkbox"][value="1"]')).to be_present
      expect(zip_form.at_css('input[name="include_attachments"][type="checkbox"][value="1"]')).to be_present
      expect(zip_form.at_css('input[name="pdf_only"][type="checkbox"][value="1"]')).to be_present
      expect(zip_form.at_css('input[name="selection_scope"][value="explicit"]')).to be_present
      expect(zip_form.at_css('button[data-action="document-zip-selection#selectPage"]')).to be_present
      expect(zip_form.at_css('button[data-action="document-zip-selection#selectMatching"]')).to be_present
    end
  end
end
