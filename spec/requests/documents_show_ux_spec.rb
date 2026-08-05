require "rails_helper"
require "fileutils"

RSpec.describe "documents#show UX patterns", type: :request do
  let(:company) { create(:company) }
  let(:internal_user) { create(:user, :internal) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "UXPAT", name: "UX Pattern Project") }
  let(:document) { create(:document, project:, title: "UX Pattern Document", slug: "ux-pattern-doc", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def write_site_file(version, relative_path, body)
    absolute_path = version.site_root_absolute_path.join(relative_path)
    FileUtils.mkdir_p(absolute_path.dirname)
    File.write(absolute_path, body)
  end

  describe "ロール別表示制御" do
    context "Internal admin" do
      before do
        sign_in_as(internal_user)
        get project_document_path(project, document.slug)
      end

      it "displays all management sections including approval requests" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("#approval-requests")).to be_present
        expect(parsed_html.at_css("#approval-requests form")).to be_present
      end

      it "displays drag-and-drop upload overlay" do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("manual-document-upload")
      end

      it "displays confirmation request form" do
        expect(response).to have_http_status(:ok)
        approval_section = parsed_html.at_css("#approval-requests")
        expect(approval_section).to be_present
        expect(approval_section.css("form")).to be_present
      end

      it "displays 確認事項 tab in comment workspace" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("#document-comment-tab-review")).to be_present
      end

      xit "displays handoff summary" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("#document-comment-handoff-summary")).to be_present
      end
    end

    context "External user" do
      before do
        sign_in_as(external_user)
        get project_document_path(project, document.slug)
      end

      it "does not display approval requests section" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("#approval-requests")).to be_nil
      end

      xit "does not display drag-and-drop upload area" do
        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("manual-document-upload")
      end

      it "does not display 確認事項 tab" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("#document-comment-tab-review")).to be_nil
      end

      it "does not display confirmation request form" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("#approval-requests")).to be_nil
      end

      it "does not display handoff summary" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("#document-comment-handoff-summary")).to be_nil
      end

      it "displays only navigation and download actions" do
        expect(response).to have_http_status(:ok)
        html = parsed_html
        header_links = html.css(".page-header__actions a").map { |a| a["href"] }
        expect(header_links).to include(project_path(project))
        expect(header_links).to include(project_documents_path(project))
        # Internal-only popout link should not be present
        expect(response.body).not_to include("ポップアウト")
      end
    end
  end

  describe "本文あり/なし分岐" do
    context "rendered view available" do
      before do
        version.update!(site_build_path: "docs/ux-pattern-doc", markdown_entry_path: "docs/ux-pattern-doc/index")
        write_site_file(version, "docs/ux-pattern-doc/index.html", "<html><body><h1>Test</h1></body></html>")

        sign_in_as(internal_user)
        get project_document_path(project, document.slug)
      end

      after do
        FileUtils.rm_rf(version.site_root_absolute_path) if version&.id
      end

      it "renders iframe viewer" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("iframe.site-viewer-frame")).to be_present
      end

      it "renders detail sections inside document-context-drawer" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("details.document-context-drawer")).to be_present
      end

      it "renders comment workspace in floating mode" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css(".document-comment-workspace--floating")).to be_present
        expect(parsed_html.at_css(".document-comment-workspace--inline")).to be_nil
      end
    end

    context "no rendered view" do
      before do
        version.update!(site_build_path: nil, markdown_entry_path: nil)
        sign_in_as(internal_user)
        get project_document_path(project, document.slug)
      end

      it "does not render iframe" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("iframe.site-viewer-frame")).to be_nil
      end

      it "renders detail sections inline (not in drawer)" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css("details.document-context-drawer")).to be_nil
        expect(parsed_html.at_css("#attributes")).to be_present
      end

      it "renders comment workspace in inline mode" do
        expect(response).to have_http_status(:ok)
        expect(parsed_html.at_css(".document-comment-workspace--inline")).to be_present
        expect(parsed_html.at_css(".document-comment-workspace--floating")).to be_nil
      end
    end
  end

  describe "パンくず" do
    context "版指定なし" do
      it "renders 2-level breadcrumb (project → document)" do
        sign_in_as(internal_user)
        get project_document_path(project, document.slug)

        expect(response).to have_http_status(:ok)
        html = parsed_html
        breadcrumb_nav = html.at_css('nav[aria-label="パンくず"]')
        expect(breadcrumb_nav).to be_present

        items = breadcrumb_nav.css("ol li")
        expect(items.size).to eq(2)

        # First item: project link
        first_link = items[0].at_css("a")
        expect(first_link).to be_present
        expect(first_link["href"]).to eq(project_documents_path(project))

        # Last item: current page (no link, aria-current)
        last_item = items.last
        expect(last_item["aria-current"]).to eq("page")
        expect(last_item.at_css("a")).to be_nil
      end
    end

    context "版指定あり" do
      it "renders 3-level breadcrumb (project → document → version)" do
        sign_in_as(internal_user)
        get project_document_path(project, document.slug, version_id: version.public_id)

        expect(response).to have_http_status(:ok)
        html = parsed_html
        breadcrumb_nav = html.at_css('nav[aria-label="パンくず"]')
        expect(breadcrumb_nav).to be_present

        items = breadcrumb_nav.css("ol li")
        expect(items.size).to eq(3)

        # First item: project link
        first_link = items[0].at_css("a")
        expect(first_link).to be_present
        expect(first_link["href"]).to eq(project_documents_path(project))

        # Second item: document link
        second_link = items[1].at_css("a")
        expect(second_link).to be_present
        expect(second_link["href"]).to eq(project_document_path(project, document.slug))

        # Last item: version label (current page, no link)
        last_item = items.last
        expect(last_item["aria-current"]).to eq("page")
        expect(last_item.at_css("a")).to be_nil
      end
    end
  end
end
