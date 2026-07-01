require "rails_helper"

RSpec.describe "Admin document lifecycle dry-run candidates", type: :request do
  let(:admin_user) { create(:user, :internal) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_href(text)
    parsed_html.css("a[href]").find { |link| link.text.squish == text }&.[]("href")
  end

  def query_for(link_text)
    Rack::Utils.parse_nested_query(URI.parse(link_href(link_text)).query)
  end

  def selected_archive_action_value
    parsed_html.at_xpath('//select[@name="bulk_edit[archive_action]"]/option[@selected]')&.[]("value")
  end

  it "links active filtered results to an archive dry-run without changing document state" do
    project = create(:project, code: "LIFE-A", name: "Lifecycle Active")
    active_document = create(:document, project:, title: "Archive Candidate", retention_until: 1.day.ago)
    archived_document = create(:document, project:, title: "Already Archived", retention_until: 1.day.ago)
    archived_document.archive!(actor: admin_user)

    sign_in_as(admin_user)

    expect do
      get admin_documents_path, params: { q: "LIFE-A", archived: "active", retention: "due" }
    end.not_to change { active_document.reload.archived? }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("アーカイブdry-run候補として開く")
    expect(page_text).to include("有効な文書1件だけを候補にします")
    expect(page_text).not_to include("復元dry-run候補として開く")

    query = query_for("アーカイブdry-run候補として開く")
    expect(query.fetch("source")).to eq("admin_documents")
    expect(query.fetch("lifecycle_purpose")).to eq("archive")
    expect(query.fetch("candidate_document_ids").map(&:to_i)).to eq([active_document.id])
    expect(query.fetch("candidate_document_ids").map(&:to_i)).not_to include(archived_document.id)
    expect(query.fetch("source_filter_summaries")).to include("目的: archive dry-run", "対象状態: 有効")
  end

  it "links archived filtered results to a restore dry-run without changing document state" do
    project = create(:project, code: "LIFE-R", name: "Lifecycle Restore")
    active_document = create(:document, project:, title: "Active Document", discard_candidate_at: 1.day.ago)
    archived_document = create(:document, project:, title: "Restore Candidate", discard_candidate_at: 1.day.ago)
    archived_document.archive!(actor: admin_user)

    sign_in_as(admin_user)

    expect do
      get admin_documents_path, params: { q: "LIFE-R", archived: "archived", discard: "due" }
    end.not_to change { archived_document.reload.archived? }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("復元dry-run候補として開く")
    expect(page_text).to include("アーカイブ済み文書1件だけを候補にします")
    expect(page_text).not_to include("アーカイブdry-run候補として開く")

    query = query_for("復元dry-run候補として開く")
    expect(query.fetch("source")).to eq("admin_documents")
    expect(query.fetch("lifecycle_purpose")).to eq("restore")
    expect(query.fetch("candidate_document_ids").map(&:to_i)).to eq([archived_document.id])
    expect(query.fetch("candidate_document_ids").map(&:to_i)).not_to include(active_document.id)
    expect(query.fetch("source_filter_summaries")).to include("目的: restore dry-run", "対象状態: アーカイブ済み")
  end

  it "splits mixed active and archived results into separate dry-run candidates" do
    project = create(:project, code: "LIFE-M", name: "Lifecycle Mixed")
    active_document = create(:document, project:, title: "Mixed Active")
    archived_document = create(:document, project:, title: "Mixed Archived")
    archived_document.archive!(actor: admin_user)

    sign_in_as(admin_user)

    get admin_documents_path, params: { q: "LIFE-M" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("混在した検索結果は、アーカイブ候補と復元候補を分けて一括編集dry-runへ渡します。")
    expect(query_for("アーカイブdry-run候補として開く").fetch("candidate_document_ids").map(&:to_i)).to eq([active_document.id])
    expect(query_for("復元dry-run候補として開く").fetch("candidate_document_ids").map(&:to_i)).to eq([archived_document.id])
  end

  it "preselects archive and restore actions on the bulk edit dry-run screen" do
    active_document = create(:document, title: "Archive Preset")
    archived_document = create(:document, title: "Restore Preset")
    archived_document.archive!(actor: admin_user)

    sign_in_as(admin_user)

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      lifecycle_purpose: "archive",
      candidate_document_ids: [active_document.id],
      source_filter_summaries: ["目的: archive dry-run", "対象状態: 有効"]
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("目的: アーカイブ dry-run候補")
    expect(selected_archive_action_value).to eq("archive")
    expect(parsed_html.at_css(%(input[type="hidden"][name="lifecycle_purpose"][value="archive"]))).to be_present
    expect(page_text).to include("文書状態はまだ変更されません")

    get new_admin_bulk_edit_dry_run_path, params: {
      source: "admin_documents",
      lifecycle_purpose: "restore",
      candidate_document_ids: [archived_document.id],
      source_filter_summaries: ["目的: restore dry-run", "対象状態: アーカイブ済み"]
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("目的: 復元 dry-run候補")
    expect(selected_archive_action_value).to eq("restore")
    expect(parsed_html.at_css(%(input[type="hidden"][name="lifecycle_purpose"][value="restore"]))).to be_present
  end
end
