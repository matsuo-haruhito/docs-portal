require "rails_helper"

RSpec.describe DocumentsHelper, type: :helper do
  describe "document tree links" do
    let(:user) { create(:user, :internal) }
    let(:project) { create(:project, code: "TREE") }
    let(:document) { create(:document, project:, title: "操作説明", slug: "manual") }

    before do
      helper.define_singleton_method(:current_user) { user }
    end

    it "links a document node directly to its rendered HTML page when available" do
      version = create(:document_version, document:, site_build_path: "docs/manual")
      document.update!(latest_version: version, updated_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
      FileUtils.mkdir_p(version.site_root_absolute_path.join("docs/manual"))
      File.write(version.site_root_absolute_path.join("docs/manual/index.html"), "<html></html>")

      expect(helper.tree_item_path(document)).to eq(
        helper.project_site_path(project, site_path: "docs/manual", version_id: version.public_id)
      )
      expect(helper.tree_item_detail_path(document)).to eq(helper.project_document_path(project, document.slug))
      expect(helper.tree_item_updated_label(document)).to eq("2026-05-01")
      expect(helper.tree_item_html_available?(document)).to be(true)
    end

    it "falls back to the document detail page when rendered HTML is unavailable" do
      document.update!(latest_version: create(:document_version, document:))

      expect(helper.tree_item_path(document)).to eq(helper.project_document_path(project, document.slug))
      expect(helper.tree_item_html_available?(document)).to be(false)
    end

    it "links a project node to its default rendered site and keeps a project top link" do
      version = create(:document_version, document:, site_build_path: "docs/manual", published_at: Time.zone.local(2026, 5, 1, 9, 0, 0))
      document.update!(latest_version: version)
      FileUtils.mkdir_p(version.site_root_absolute_path.join("docs/manual"))
      File.write(version.site_root_absolute_path.join("docs/manual/index.html"), "<html></html>")

      expect(helper.tree_item_path(project)).to eq(
        helper.project_site_path(project, site_path: "docs/manual", version_id: version.public_id)
      )
      expect(helper.tree_item_detail_path(project)).to eq(helper.project_path(project))
    end
  end
end
