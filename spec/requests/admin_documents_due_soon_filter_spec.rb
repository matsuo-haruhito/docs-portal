require "rails_helper"

RSpec.describe "Admin document due soon filters", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def title_targets
    parsed_html.css("table tbody tr").filter_map do |row|
      row.at_css(%(td[data-rails-table-preferences-column-key="title"] a))&.[]("href")
    end
  end

  def filter_chip_texts
    parsed_html.css(".admin-filter-chip").map { |node| node.text.squish }
  end

  def lifecycle_disclosure
    parsed_html.css("details.filter-details").find do |details|
      details.at_css("summary")&.text&.squish == "lifecycle確認"
    end
  end

  it "filters retention dates due soon without mixing overdue, missing, or far future documents" do
    project = create(:project, code: "DUE-SOON", name: "Due Soon Project")
    due_soon_document = create(:document, project:, title: "Retention Soon", slug: "retention-soon", retention_until: 7.days.from_now)
    overdue_document = create(:document, project:, title: "Retention Overdue", slug: "retention-overdue", retention_until: 2.days.ago)
    far_future_document = create(:document, project:, title: "Retention Far", slug: "retention-far", retention_until: 45.days.from_now)
    missing_document = create(:document, project:, title: "Retention Missing", slug: "retention-missing", retention_until: nil)

    sign_in_as(admin_user)

    get admin_documents_path, params: { q: "DUE-SOON", retention: "due_soon" }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".admin-list-meta__count")&.text&.squish).to eq("1件")
    expect(filter_chip_texts).to include("保管期限: 保管期限が30日以内")
    expect(lifecycle_disclosure).to be_present
    expect(lifecycle_disclosure["open"]).to be_nil
    expect(lifecycle_disclosure.at_css('a[href*="lifecycle_handoff"]')).to be_present
    expect(title_targets).to contain_exactly(project_document_path(project, due_soon_document.slug))
    expect(title_targets).not_to include(
      project_document_path(project, overdue_document.slug),
      project_document_path(project, far_future_document.slug),
      project_document_path(project, missing_document.slug)
    )
  end

  it "filters discard candidates due soon without changing document lifecycle state" do
    project = create(:project, code: "DISC-SOON", name: "Discard Soon Project")
    due_soon_document = create(:document, project:, title: "Discard Soon", slug: "discard-soon", discard_candidate_at: 10.days.from_now)
    overdue_document = create(:document, project:, title: "Discard Overdue", slug: "discard-overdue", discard_candidate_at: 1.day.ago)
    far_future_document = create(:document, project:, title: "Discard Far", slug: "discard-far", discard_candidate_at: 60.days.from_now)
    missing_document = create(:document, project:, title: "Discard Missing", slug: "discard-missing", discard_candidate_at: nil)

    sign_in_as(admin_user)

    expect do
      get admin_documents_path, params: { q: "DISC-SOON", discard: "due_soon" }
    end.not_to change { Document.order(:id).pluck(:id, :archived_at, :discard_candidate_at) }

    expect(response).to have_http_status(:ok)
    expect(parsed_html.at_css(".admin-list-meta__count")&.text&.squish).to eq("1件")
    expect(filter_chip_texts).to include("廃棄候補: 廃棄候補が30日以内")
    expect(lifecycle_disclosure).to be_present
    expect(lifecycle_disclosure["open"]).to be_nil
    expect(title_targets).to contain_exactly(project_document_path(project, due_soon_document.slug))
    expect(title_targets).not_to include(
      project_document_path(project, overdue_document.slug),
      project_document_path(project, far_future_document.slug),
      project_document_path(project, missing_document.slug)
    )
  end
end
