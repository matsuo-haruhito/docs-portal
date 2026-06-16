require "rails_helper"

RSpec.describe "Admin dashboard storage breakdown", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def storage_area(key: :document_files, label: "DocumentFile 実体", relative_path: "storage/document_files")
    StorageUsageSummary::Area.new(
      key:,
      label:,
      relative_path:,
      description: "アップロード、ZIP/Git/外部同期で取り込まれた文書添付の正本",
      bytes: 1024,
      file_count: 2,
      breakdown_entries: []
    )
  end

  it "shows the bounded Project / Document breakdown without raw storage paths" do
    breakdown_entry = StorageUsageSummary::DocumentFileBreakdownEntry.new(
      project_code: "DASH3248",
      project_name: "Storage Project",
      document_title: "Storage Heavy Document",
      document_slug: "storage-heavy-document",
      bytes: 2048,
      file_count: 3,
      missing_file_count: 1,
      latest_updated_at: Time.zone.local(2026, 6, 16, 9, 30, 0)
    )
    summary = StorageUsageSummary::Result.new(
      areas: [storage_area],
      document_file_breakdown_entries: [breakdown_entry]
    )
    allow(StorageUsageSummary).to receive(:new).and_return(instance_double(StorageUsageSummary, call: summary))

    sign_in_as(admin_user)

    get admin_root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("DocumentFile 実体の Project / Document 上位")
    expect(response.body).to include("storage/document_files に紐づく DocumentFile 実体だけ")
    expect(response.body).to include("上位5件")
    expect(response.body).to include("削除・archive・cleanup・retention policy 決定には使いません")
    expect(response.body).to include("raw absolute path や外部 storage metadata は表示しません")
    expect(response.body).to include("DASH3248")
    expect(response.body).to include("Storage Project")
    expect(response.body).to include("Storage Heavy Document")
    expect(response.body).to include(project_document_path("DASH3248", "storage-heavy-document"))
    expect(response.body).to include("3")
    expect(response.body).to include("1")
    expect(response.body).to include("path は表示しません")
    expect(response.body).to include("2 KB")
    expect(response.body).to include(I18n.l(breakdown_entry.latest_updated_at, format: :short))
    expect(response.body).not_to include("/storage/document_files/")
    expect(response.body).not_to include("secret=")
  end
end
