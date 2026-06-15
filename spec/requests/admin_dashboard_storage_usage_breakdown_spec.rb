require "rails_helper"

RSpec.describe "Admin dashboard storage usage breakdown", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def storage_usage_section
    parsed_html.css("section.card").find { |section| section.at_css("h2")&.text&.squish == "Storage使用量" }
  end

  it "shows safe bounded breakdown entries for each storage area" do
    summary = StorageUsageSummary::Result.new(
      areas: [
        StorageUsageSummary::Area.new(
          key: :document_files,
          label: "DocumentFile 実体",
          relative_path: "storage/document_files",
          description: "アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本",
          bytes: 1024,
          file_count: 2,
          breakdown_entries: [
            StorageUsageSummary::BreakdownEntry.new(relative_path: "storage/document_files/project-a", bytes: 1024, file_count: 2)
          ]
        ),
        StorageUsageSummary::Area.new(
          key: :docs_sites,
          label: "Docs site build",
          relative_path: "storage/docs_sites",
          description: "Docusaurus などで生成した文書表示用 site artifact",
          bytes: 2048,
          file_count: 3,
          breakdown_entries: [
            StorageUsageSummary::BreakdownEntry.new(relative_path: "storage/docs_sites/site-a", bytes: 2048, file_count: 3)
          ]
        ),
        StorageUsageSummary::Area.new(
          key: :imports,
          label: "Import staging",
          relative_path: "storage/imports",
          description: "ZIP / manual upload dry-run などの一時確認 artifact",
          bytes: 0,
          file_count: 0,
          breakdown_entries: []
        )
      ]
    )
    allow(StorageUsageSummary).to receive(:new).and_return(instance_double(StorageUsageSummary, call: summary))

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("Storage使用量")
    expect(page_text).to include("大きい内訳")
    expect(response.body).to include("storage/document_files/project-a")
    expect(response.body).to include("storage/docs_sites/site-a")
    expect(page_text).to include("2 file")
    expect(page_text).to include("3 file")
    expect(page_text).to include("内訳なし")
    expect(storage_usage_section.to_html).not_to include(Rails.root.to_s)
  end
end
