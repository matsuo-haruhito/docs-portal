require "rails_helper"

RSpec.describe "Document delivery log active filters summary", type: :request do
  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:internal_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.gsub(/[[:space:]]+/, " ").strip
  end

  def localized_status_label(status)
    I18n.t("labels.document_delivery_logs.status.#{status}", default: status.to_s)
  end

  def localized_delivery_type_label(delivery_type)
    I18n.t("labels.document_delivery_logs.delivery_type.#{delivery_type}", default: delivery_type.to_s)
  end

  def create_delivery_log_at(created_at, attributes = {})
    create(
      :document_delivery_log,
      {
        project:,
        document:,
        sender: external_user,
        status: :draft,
        delivery_type: :portal_link,
        to_addresses: "recipient@example.com",
        subject: "Delivery notice"
      }.merge(attributes)
    ).tap do |log|
      log.update_columns(created_at:, updated_at: created_at)
    end
  end

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "does not show the active filter summary when no filter is active" do
    create_delivery_log_at(Time.zone.local(2026, 1, 15, 12, 0, 0))

    sign_in_as(internal_user)

    get document_delivery_logs_path

    expect(response).to have_http_status(:ok)
    expect(page_text).not_to include("現在の絞り込み条件:")
  end

  it "summarizes combined query, date, status, and delivery type filters with localized labels" do
    matching_log = create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      status: :failed,
      delivery_type: :portal_link,
      sent_at: Time.zone.local(2026, 1, 16, 10, 30, 0),
      to_addresses: "date-hit@example.com",
      subject: "Date needle"
    )
    create_delivery_log_at(
      Time.zone.local(2026, 1, 15, 12, 0, 0),
      status: :sent,
      delivery_type: :portal_link,
      sent_at: Time.zone.local(2026, 1, 16, 10, 30, 0),
      to_addresses: "wrong-status@example.com",
      subject: "Date needle"
    )

    sign_in_as(internal_user)

    get document_delivery_logs_path, params: {
      q: "Date needle",
      status: :failed,
      delivery_type: :portal_link,
      created_from: "2026-01-10",
      created_to: "2026-01-20",
      sent_from: "2026-01-11",
      sent_to: "2026-01-21"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include(matching_log.to_addresses)
    expect(page_text).not_to include("wrong-status@example.com")
    expect(page_text).to include("現在の絞り込み条件: 検索語: Date needle")
    expect(page_text).to include("作成日: 2026-01-10 から 2026-01-20 まで")
    expect(page_text).to include("送信日時: 2026-01-11 から 2026-01-21 まで")
    expect(page_text).to include("状態: #{localized_status_label(:failed)}")
    expect(page_text).to include("方式: #{localized_delivery_type_label(:portal_link)}")
    expect(page_text).to include("表示件数はこの条件に一致した履歴のうち、先頭から表示している件数です。")
    expect(page_text).to include("表示範囲: 1件中1件を表示しています。")
  end

  it "keeps the active filter summary visible in the filtered empty state" do
    sign_in_as(internal_user)

    get document_delivery_logs_path, params: {
      q: "missing recipient",
      status: :failed,
      delivery_type: :portal_link,
      created_from: "2026-01-10",
      sent_to: "2026-01-21"
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("現在の絞り込み条件: 検索語: missing recipient")
    expect(page_text).to include("作成日: 2026-01-10 から 指定なし まで")
    expect(page_text).to include("送信日時: 指定なし から 2026-01-21 まで")
    expect(page_text).to include("状態: #{localized_status_label(:failed)}")
    expect(page_text).to include("方式: #{localized_delivery_type_label(:portal_link)}")
    expect(page_text).to include("検索条件に一致する送付履歴はありません。")
    expect(page_text).to include("すべての送付履歴を見る")
  end
end
