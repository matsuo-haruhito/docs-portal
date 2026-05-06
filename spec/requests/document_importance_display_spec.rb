require "rails_helper"

RSpec.describe "Document importance display", type: :request do
  let(:project) { create(:project, code: "proj-importance") }
  let(:user) { create(:user, :internal) }

  before do
    sign_in_as(user)
  end

  def create_ranked_document(title:, slug:, importance_level:, recommended_sort_order:)
    document = create(
      :document,
      project:,
      title:,
      slug:,
      importance_level:,
      recommended_sort_order:
    )
    version = create(:document_version, document:)
    document.update!(latest_version: version)
    document
  end

  it "prioritizes important documents on project and document index pages" do
    reference = create_ranked_document(title: "Reference", slug: "reference", importance_level: :reference, recommended_sort_order: 0)
    important = create_ranked_document(title: "Important", slug: "important", importance_level: :important, recommended_sort_order: 2)
    critical = create_ranked_document(title: "Critical", slug: "critical", importance_level: :critical, recommended_sort_order: 1)

    get project_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("優先して確認したい資料")
    expect(response.body.index("Critical")).to be < response.body.index("Important")
    expect(response.body.index("Important")).to be < response.body.index("Reference")

    get project_documents_path(project)
    expect(response).to have_http_status(:ok)
    expect(response.body.index("Critical")).to be < response.body.index("Important")
    expect(response.body.index("Important")).to be < response.body.index("Reference")
  end

  it "shows importance metadata on the document detail page" do
    document = create_ranked_document(title: "Critical", slug: "critical", importance_level: :critical, recommended_sort_order: 1)

    get project_document_path(project, document.slug)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("重要度:")
    expect(response.body).to include("critical")
  end
end
