require "csv"
require "rails_helper"

RSpec.describe "Admin missing document files CSV handoff", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "MISS", name: "Missing Project") }
  let(:other_project) { create(:project, code: "OTHER", name: "Other Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def parsed_csv
    CSV.parse(response.body, headers: true)
  end

  def missing_file_for(document, file_name:, storage_key:)
    version = create(:document_version, document:)
    create(:document_file, document_version: version, file_name:, storage_key:)
  end

  it "links to a read-only CSV handoff that keeps the current filters" do
    document = create(:document, project:, title: "Safety Runbook", slug: "safety-runbook")
    missing_file_for(document, file_name: "handoff.pdf", storage_key: "manuals/safety/handoff.pdf")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(project_id: project.id, document_q: "safety", file_q: "handoff")

    expect(response).to have_http_status(:ok)
    link = parsed_html.at_css(%(a[href*="#{admin_missing_document_files_path}.csv"]))
    expect(link).to be_present
    expect(link.text.squish).to eq("表示中の欠落候補をCSVで引き継ぐ")
    expect(link["href"]).to include("project_id=#{project.id}")
    expect(link["href"]).to include("document_q=safety")
    expect(link["href"]).to include("file_q=handoff")
    expect(response.body).to include("CSV handoff は現在の条件と表示中の先頭100件だけを read-only に引き継ぎます。")
  end

  it "exports the filtered bounded missing files without raw absolute paths" do
    matching_document = create(:document, project:, title: "Safety Runbook", slug: "safety-runbook")
    other_document = create(:document, project: other_project, title: "Other Runbook", slug: "other-runbook")
    101.times do |index|
      missing_file_for(
        matching_document,
        file_name: "missing-#{index}.pdf",
        storage_key: "imports/missing-#{index}.pdf"
      )
    end
    hidden_file = missing_file_for(other_document, file_name: "other.pdf", storage_key: "other/missing.pdf")

    sign_in_as(admin_user)

    get admin_missing_document_files_path(format: :csv, project_id: project.id)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    expect(response.headers.fetch("Content-Disposition")).to include("missing-document-files-#{Time.zone.today.iso8601}.csv")

    csv = parsed_csv
    expect(csv.headers).to eq([
      "案件コード",
      "案件名",
      "文書名",
      "document slug",
      "版",
      "ファイル名",
      "Storage key",
      "Expected path preview",
      "handoff note"
    ])
    expect(csv.size).to eq(Admin::MissingDocumentFilesController::DETAIL_LIMIT)
    expect(csv[0].to_h).to include(
      "案件コード" => "MISS",
      "案件名" => "Missing Project",
      "文書名" => "Safety Runbook",
      "document slug" => "safety-runbook",
      "ファイル名" => "missing-0.pdf",
      "Storage key" => "imports/missing-0.pdf",
      "Expected path preview" => "storage/document_files/imports/missing-0.pdf"
    )
    expect(csv[0]["handoff note"]).to include("read-only handoff")
    expect(response.body).to include("missing-99.pdf")
    expect(response.body).not_to include("missing-100.pdf")
    expect(response.body).not_to include("Other Project")
    expect(response.body).not_to include(hidden_file.absolute_path.to_s)
    expect(response.body).not_to include(Rails.root.to_s)
  end

  it "keeps the CSV endpoint admin-only" do
    sign_in_as(create(:user, :company_master_admin))

    get admin_missing_document_files_path(format: :csv)

    expect(response).to have_http_status(:forbidden)
  end
end
