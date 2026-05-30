require "rails_helper"

RSpec.describe "Access request empty states", type: :request do
  let(:user) { create(:user, :external) }

  def parsed_html
    Nokogiri::HTML.parse(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def link_labels
    parsed_html.css("a").map { _1.text.squish }
  end

  it "shows the unsubmitted empty state when the user has no access requests" do
    sign_in_as(user)

    get access_requests_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("送信済みのアクセス申請はありません。")
    expect(page_text).not_to include("申請中のアクセス申請はありません。")
    expect(link_labels).to include("すべて (0)", "申請中 (0)", "承認済み (0)", "却下 (0)", "取消済み (0)")
  end

  it "shows a status-filtered empty state and keeps the all-requests return link" do
    approver = create(:user, :internal)
    create(:access_request, requester: user, status: :approved, approver:, approved_at: Time.current)
    create(:access_request, status: :pending)

    sign_in_as(user)

    get access_requests_path(status: :pending)

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("申請中のアクセス申請はありません。")
    expect(page_text).not_to include("送信済みのアクセス申請はありません。")
    expect(page_text).not_to include("検索条件に一致するアクセス申請はありません。")
    expect(link_labels).to include("すべて (1)", "申請中 (0)", "承認済み (1)", "すべての申請を見る")
  end
end
