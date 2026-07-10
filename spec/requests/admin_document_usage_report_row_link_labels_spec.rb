require "rails_helper"

RSpec.describe "Admin document usage report row link labels", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "USAGE", name: "Usage Project") }
  let(:company) { create(:company) }
  let(:viewer) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def row_link(text:, href:)
    parsed_html.css("a[href='#{href}']").find do |link|
      link.text.squish == text
    end
  end

  it "keeps row action text compact while adding document-specific accessible names" do
    create(:access_log, project:, document:, user: viewer, company:, action_type: :view, accessed_at: Time.zone.local(2026, 5, 1, 10, 0, 0))
    create(:read_confirmation, document:, user: viewer, confirmed_at: Time.zone.local(2026, 5, 1, 12, 0, 0))

    sign_in_as(admin_user)

    get admin_document_usage_reports_path(project_id: project.id)

    expect(response).to have_http_status(:ok)

    audit_log_link = row_link(
      text: "監査ログへ",
      href: admin_access_logs_path(project_id: project.id, document_q: document.slug)
    )
    expect(audit_log_link).to be_present
    expect(audit_log_link["aria-label"]).to eq("Manual (manual) の監査ログへ")

    read_confirmation_link = row_link(
      text: "内訳へ",
      href: admin_read_confirmations_path(project_id: project.id, document_slug: document.slug)
    )
    expect(read_confirmation_link).to be_present
    expect(read_confirmation_link["aria-label"]).to eq("Manual (manual) の既読確認内訳へ")
  end
end
