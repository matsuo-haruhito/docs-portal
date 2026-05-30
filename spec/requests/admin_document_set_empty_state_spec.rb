require "rails_helper"

RSpec.describe "Admin document set empty state", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:empty_project) { create(:project, name: "Empty Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def action_targets
    parsed_html.css("a[href]").map { |node| node["href"] }
  end

  it "shows git and zip import guidance when the selected project has no documents" do
    sign_in_as(admin)

    post admin_document_sets_path, params: {
      document_set: {
        project_id: empty_project.id,
        name: "",
        description: "empty project setup",
        set_type: "delivery",
        visibility_policy: "restricted_external",
        sort_order: 0
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("まだ対象文書がありません。")
    expect(page_text).to include("この案件に文書を取り込むと、ここで対象文書を選べます。")
    expect(page_text).not_to include("案件を選ぶと対象文書を設定できます。")
    expect(action_targets).to include(
      admin_git_import_sources_path,
      admin_git_import_runs_path,
      new_admin_zip_import_path
    )
  end
end
