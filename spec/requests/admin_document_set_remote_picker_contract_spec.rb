require "rails_helper"

RSpec.describe "Admin document set remote picker contract", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Remote Picker Project") }

  def json_body
    JSON.parse(response.body)
  end

  it "caps remote document picker results to 20 project-scoped documents" do
    matching_documents = 21.times.map do |index|
      document = create(
        :document,
        project:,
        title: "Remote limit candidate #{index.to_s.rjust(2, "0")}",
        slug: "remote-limit-candidate-#{index.to_s.rjust(2, "0")}"
      )
      create(:document_version, document:, version_label: "v#{index}")
      document.reload
    end
    other_project = create(:project, name: "Other Remote Picker Project")
    other_document = create(
      :document,
      project: other_project,
      title: "Remote limit candidate outside",
      slug: "remote-limit-candidate-outside"
    )

    sign_in_as(admin)

    get document_search_admin_document_sets_path, params: { project_id: project.id, q: "remote-limit-candidate" }

    expect(response).to have_http_status(:ok)

    documents = json_body.fetch("documents")
    expect(documents.size).to eq(20)
    expect(json_body.fetch("options")).to eq(documents)
    expect(documents.map { |item| item.fetch("id") }).to all(be_in(matching_documents.map(&:id)))
    expect(documents.map { |item| item.fetch("id") }).not_to include(other_document.id)
    expect(documents).to all(include("id", "title", "slug", "text", "latest_version_label"))
  end
end
