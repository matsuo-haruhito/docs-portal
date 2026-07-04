require "rails_helper"
require "csv"

RSpec.describe "Admin storage area usage details", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def parsed_csv
    CSV.parse(response.body, headers: true)
  end

  def storage_area_entry(relative_path:, bytes:, file_count:, latest_updated_at:, kind_hint:)
    StorageUsageSummary::StorageAreaDetailEntry.new(
      relative_path:,
      bytes:,
      file_count:,
      latest_updated_at:,
      kind_hint:
    )
  end

  def storage_area_detail(area_key:, area_label:, relative_path:, entries:, total_count: entries.size, file_count: entries.sum(&:file_count), bytes: entries.sum(&:bytes))
    StorageUsageSummary::StorageAreaDetailResult.new(
      area_key:,
      area_label:,
      relative_path:,
      description: "read-only #{area_label} detail",
      entries:,
      total_count:,
      file_count:,
      bytes:,
      limit: StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT
    )
  end

  def stub_storage_summary(detail_method, detail)
    allow(StorageUsageSummary).to receive(:new).and_return(instance_double(StorageUsageSummary, detail_method => detail))
  end

  it "keeps docs_sites and imports CSV handoff admin-only" do
    sign_in_as(create(:user, :company_master_admin))
    get admin_storage_usage_docs_sites_path(format: :csv)
    expect(response).to have_http_status(:forbidden)

    sign_in_as(create(:user, :external))
    get admin_storage_usage_imports_path(format: :csv)
    expect(response).to have_http_status(:forbidden)
  end

  it "shows CSV handoff links and read-only role cues on both storage area detail pages" do
    docs_detail = storage_area_detail(
      area_key: :docs_sites,
      area_label: "Docs site build",
      relative_path: "storage/docs_sites",
      entries: []
    )
    stub_storage_summary(:docs_site_detail, docs_detail)
    sign_in_as(admin_user)

    get admin_storage_usage_docs_sites_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_storage_usage_docs_sites_path(format: :csv))
    expect(page_text).to include("CSV handoff")
    expect(page_text).to include("DocumentFile 実体 export とは別です")
    expect(page_text).to include("CSV handoff でも 0 件状態を示す summary row")
    expect(response.body).not_to include(Rails.root.to_s)

    imports_detail = storage_area_detail(
      area_key: :imports,
      area_label: "Import staging",
      relative_path: "storage/imports",
      entries: []
    )
    stub_storage_summary(:import_detail, imports_detail)

    get admin_storage_usage_imports_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include(admin_storage_usage_imports_path(format: :csv))
    expect(page_text).to include("CSV handoff")
    expect(page_text).to include("DocumentFile 実体 export とは別です")
    expect(page_text).to include("CSV handoff でも 0 件状態を示す summary row")
    expect(response.body).not_to include(Rails.root.to_s)
  end

  it "exports docs_sites bounded entries as a read-only CSV handoff" do
    latest_update = Time.zone.local(2026, 7, 3, 12, 0, 0)
    entries = StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT.times.map do |index|
      storage_area_entry(
        relative_path: "storage/docs_sites/site-#{index}",
        bytes: 2048 - index,
        file_count: 3,
        latest_updated_at: latest_update,
        kind_hint: "generated site directory"
      )
    end
    detail = storage_area_detail(
      area_key: :docs_sites,
      area_label: "Docs site build",
      relative_path: "storage/docs_sites",
      entries:,
      total_count: StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT + 2,
      file_count: 81,
      bytes: 4096
    )
    stub_storage_summary(:docs_site_detail, detail)
    sign_in_as(admin_user)

    get admin_storage_usage_docs_sites_path(format: :csv)

    expect(response).to have_http_status(:ok)
    expect(response.media_type).to eq("text/csv")
    rows = parsed_csv
    expect(rows.size).to eq(StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT)
    expect(rows.headers).to include(
      "scope_status",
      "area_key",
      "area_label",
      "area_relative_path",
      "total_entries",
      "displayed_entries",
      "display_limit",
      "safe_relative_path",
      "kind_hint",
      "read_only_note"
    )
    expect(rows.map { _1["scope_status"] }.uniq).to eq(["limited_to_bounded_entries"])
    expect(rows.map { _1["area_key"] }.uniq).to eq(["docs_sites"])
    expect(rows.map { _1["total_entries"] }.uniq).to eq([(StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT + 2).to_s])
    expect(rows.map { _1["displayed_entries"] }.uniq).to eq([StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT.to_s])
    expect(rows.map { _1["display_limit"] }.uniq).to eq([StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT.to_s])

    first_row = rows.first
    expect(first_row["area_label"]).to eq("Docs site build")
    expect(first_row["area_relative_path"]).to eq("storage/docs_sites")
    expect(first_row["safe_relative_path"]).to eq("storage/docs_sites/site-0")
    expect(first_row["kind_hint"]).to eq("generated site directory")
    expect(first_row["file_count"]).to eq("3")
    expect(first_row["bytes"]).to eq("2048")
    expect(first_row["latest_updated_at"]).to eq(latest_update.iso8601)
    expect(first_row["read_only_note"]).to include("read-only bounded handoff only")
    expect(response.body).not_to include(Rails.root.to_s)
    expect(response.body).not_to include("https://storage.googleapis.com")
    expect(response.body).not_to include("signed_url")
    expect(response.body).not_to include("bucket")
  end

  it "exports imports representative entries without raw storage values" do
    latest_update = Time.zone.local(2026, 7, 3, 13, 0, 0)
    detail = storage_area_detail(
      area_key: :imports,
      area_label: "Import staging",
      relative_path: "storage/imports",
      entries: [
        storage_area_entry(
          relative_path: "storage/imports/manual-upload-42",
          bytes: 1024,
          file_count: 2,
          latest_updated_at: latest_update,
          kind_hint: "manual upload staging"
        )
      ]
    )
    stub_storage_summary(:import_detail, detail)
    sign_in_as(admin_user)

    get admin_storage_usage_imports_path(format: :csv)

    expect(response).to have_http_status(:ok)
    rows = parsed_csv
    expect(rows.size).to eq(1)
    row = rows.first
    expect(row["scope_status"]).to eq("complete_bounded_result")
    expect(row["area_key"]).to eq("imports")
    expect(row["area_label"]).to eq("Import staging")
    expect(row["safe_relative_path"]).to eq("storage/imports/manual-upload-42")
    expect(row["kind_hint"]).to eq("manual upload staging")
    expect(row["file_count"]).to eq("2")
    expect(row["bytes"]).to eq("1024")
    expect(row["read_only_note"]).to include("not a cleanup")
    expect(response.body).not_to include(Rails.root.to_s)
    expect(response.body).not_to include("https://storage.googleapis.com")
    expect(response.body).not_to include("signed_url")
    expect(response.body).not_to include("bucket")
  end

  it "exports a summary row for empty storage area CSV handoff state" do
    detail = storage_area_detail(
      area_key: :imports,
      area_label: "Import staging",
      relative_path: "storage/imports",
      entries: []
    )
    stub_storage_summary(:import_detail, detail)
    sign_in_as(admin_user)

    get admin_storage_usage_imports_path(format: :csv)

    expect(response).to have_http_status(:ok)
    rows = parsed_csv
    expect(rows.size).to eq(1)
    row = rows.first
    expect(row["scope_status"]).to eq("no_entries")
    expect(row["area_key"]).to eq("imports")
    expect(row["total_entries"]).to eq("0")
    expect(row["displayed_entries"]).to eq("0")
    expect(row["display_limit"]).to eq(StorageUsageSummary::STORAGE_AREA_DETAIL_LIMIT.to_s)
    expect(row["safe_relative_path"]).to be_nil
    expect(row["read_only_note"]).to include("does not prove cleanup")
    expect(response.body).not_to include(Rails.root.to_s)
  end
end
