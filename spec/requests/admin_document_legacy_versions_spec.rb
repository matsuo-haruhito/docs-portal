require "rails_helper"

RSpec.describe "Admin document legacy versions", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def document_rows
    parsed_html.css("table tbody tr")
  end

  def document_row_for(title)
    document_rows.find do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="title"] a))&.text&.squish == title
    end
  end

  def row_column_text(title, column_key)
    cell = document_row_for(title)&.at_css(%(td[data-rails-table-preferences-column-key="#{column_key}"]))
    cell&.xpath(".//text()")&.map { |node| node.text.squish }&.reject(&:empty?)&.join(" ")
  end

  it "shows only non-latest document versions as read-only candidates" do
    latest_only_document = create(:document, title: "Latest Only Document", slug: "latest-only")
    latest_only_version = create(
      :document_version,
      document: latest_only_document,
      version_label: "v1.0",
      status: :published,
      source_relative_path: "docs/current.md"
    )
    latest_only_document.update!(latest_version: latest_only_version)

    multi_version_document = create(:document, title: "Multi Version Document", slug: "multi-version")
    old_published_version = create(
      :document_version,
      document: multi_version_document,
      version_label: "v1.0",
      status: :published,
      source_relative_path: "imports/old.md",
      updated_at: 3.days.ago
    )
    old_draft_version = create(
      :document_version,
      document: multi_version_document,
      version_label: "manual-2026-01",
      status: :draft,
      source_relative_path: "manuals/draft.md",
      updated_at: 2.days.ago
    )
    old_archived_version = create(
      :document_version,
      document: multi_version_document,
      version_label: "v0.9",
      status: :archived,
      source_relative_path: "archive/v0.9.md",
      updated_at: 4.days.ago
    )
    latest_version = create(
      :document_version,
      document: multi_version_document,
      version_label: "v2.0",
      status: :published,
      source_relative_path: "docs/current.md",
      updated_at: 1.day.ago
    )
    multi_version_document.update!(latest_version: latest_version)

    sign_in_as(admin_user)

    get admin_documents_path

    expect(response).to have_http_status(:ok)
    expect(row_column_text("Latest Only Document", "legacy_versions")).to include(
      "候補なし",
      "latest以外の版はありません"
    )

    legacy_text = row_column_text("Multi Version Document", "legacy_versions")
    latest_text = row_column_text("Multi Version Document", "latest_version")
    action_text = row_column_text("Multi Version Document", "actions")

    expect(legacy_text).to include(
      "3件",
      "latest以外のread-only候補です。削除・archive判断はしません。",
      old_published_version.version_label,
      "source: imports/old.md",
      old_draft_version.version_label,
      "manual upload由来の可能性 / source: manuals/draft.md",
      old_archived_version.version_label,
      "source: archive/v0.9.md"
    )
    expect(legacy_text).not_to include(latest_version.version_label)
    expect(latest_text).to include(latest_version.version_label)
    expect(action_text).to include("編集", "アーカイブ", "削除")
  end
end
