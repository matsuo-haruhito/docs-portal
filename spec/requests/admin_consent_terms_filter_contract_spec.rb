require "rails_helper"

RSpec.describe "Admin consent term filters", type: :request do
  let(:admin_user) { create(:user, :internal) }

  before do
    sign_in_as(admin_user)
  end

  it "filters terms by query, active state, scope, and requirement timing" do
    matching_term = create_consent_term!(
      title: "案件利用規約",
      version_label: "2026-A",
      consent_scope: "project",
      requirement_timing: "first_view",
      active: true
    )
    create_consent_term!(
      title: "共有リンク利用規約",
      version_label: "2026-B",
      consent_scope: "shared_link",
      requirement_timing: "every_download",
      active: false
    )
    create_consent_term!(
      title: "案件利用規約",
      version_label: "2026-C",
      consent_scope: "project",
      requirement_timing: "every_download",
      active: true
    )

    get admin_consent_terms_path(
      q: "2026-A",
      active: "true",
      consent_scope: "project",
      requirement_timing: "first_view"
    )

    expect(response).to have_http_status(:ok)
    expect(listed_rows).to contain_exactly(a_string_including(matching_term.title, matching_term.version_label, "案件", "初回表示時", "利用中"))
    expect(listed_rows.join).not_to include("共有リンク利用規約", "2026-C")
    expect(search_filter["value"]).to eq("2026-A")
    expect(search_filter["maxlength"]).to eq(Admin::ConsentTermsController::CONSENT_TERM_QUERY_MAX_LENGTH.to_s)
    expect(page_text).to include("タイトルまたは版ラベルの部分一致で探せます。")
    expect(page_text).to include("検索語は最大#{Admin::ConsentTermsController::CONSENT_TERM_QUERY_MAX_LENGTH}文字です。")
    expect(selected_value(active_filter)).to eq("true")
    expect(selected_value(scope_filter)).to eq("project")
    expect(selected_value(timing_filter)).to eq("first_view")
    expect(filter_form_reset_link_texts).to include("条件をリセット")
    expect(table_column_keys).to include("title", "version_label", "consent_scope", "requirement_timing", "status", "actions")
  end

  it "normalizes long query text without widening search beyond title and version label" do
    max_length = Admin::ConsentTermsController::CONSENT_TERM_QUERY_MAX_LENGTH
    normalized_query = "a" * max_length
    long_query = "  #{normalized_query}extra-tail  "
    matching_term = create_consent_term!(title: normalized_query, version_label: "2026-A", body: "本文")
    create_consent_term!(title: "本文だけ一致", version_label: "2026-B", body: normalized_query)
    create_consent_term!(title: "長文末尾一致", version_label: "extra-tail", body: "本文")

    get admin_consent_terms_path(q: long_query)

    expect(response).to have_http_status(:ok)
    expect(search_filter["value"]).to eq(normalized_query)
    expect(page_text).to include("検索: #{normalized_query}")
    expect(page_text).not_to include("extra-tail")
    expect(listed_rows).to contain_exactly(a_string_including(matching_term.title, matching_term.version_label))
  end

  it "ignores unsupported filter values without changing the result set" do
    create_consent_term!(title: "案件利用規約", version_label: "2026-A", active: true)
    create_consent_term!(title: "共有リンク利用規約", version_label: "2026-B", consent_scope: "shared_link", active: false)

    get admin_consent_terms_path(active: "archived", consent_scope: "unknown", requirement_timing: "later")

    expect(response).to have_http_status(:ok)
    expect(listed_rows.size).to eq(2)
    expect(listed_rows.join).to include("案件利用規約", "共有リンク利用規約")
    expect(selected_value(active_filter)).to be_nil
    expect(selected_value(scope_filter)).to be_nil
    expect(selected_value(timing_filter)).to be_nil
    expect(filter_form_reset_link_texts).to include("条件をリセット")
  end

  it "shows a filtered empty state separately from the unregistered empty state" do
    create_consent_term!(title: "案件利用規約", version_label: "2026-A", active: true)

    get admin_consent_terms_path(q: "存在しない文面", active: "false")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("条件に一致する同意文面はありません。")
    expect(response.body).to include("タイトル・版ラベル、状態、種別、再同意方針の条件を見直すか、条件をリセットして一覧全体を確認してください。")
    expect(response.body).not_to include("まだ同意文面はありません。")
    expect(filter_form_reset_link_texts).to include("条件をリセット")
    expect(empty_state_reset_link_texts).to contain_exactly("条件をリセット")
  end

  it "keeps the unregistered empty state when no filters or terms exist" do
    get admin_consent_terms_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("まだ同意文面はありません。")
    expect(response.body).to include("上の「新規登録」でタイトル、版、種別、再同意方針を設定して最初の文面を保存してください。")
    expect(response.body).not_to include("条件に一致する同意文面はありません。")
    expect(reset_link_texts).to be_empty
  end

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def listed_rows
    parsed_html.css("tbody tr").map { |row| row.text.squish }
  end

  def table_column_keys
    parsed_html.css("[data-rails-table-preferences-column-key]").filter_map { |node| node["data-rails-table-preferences-column-key"] }.uniq
  end

  def search_filter
    parsed_html.at_css(%(input[name="q"]))
  end

  def active_filter
    parsed_html.at_css(%(select[name="active"]))
  end

  def scope_filter
    parsed_html.at_css(%(select[name="consent_scope"]))
  end

  def timing_filter
    parsed_html.at_css(%(select[name="requirement_timing"]))
  end

  def selected_value(select_node)
    select_node&.at_css("option[selected]")&.[]("value")
  end

  def reset_link_texts
    parsed_html.css(%(a[href="#{admin_consent_terms_path}"])).map { |link| link.text.squish }.select { |text| text == "条件をリセット" }
  end

  def filter_form_reset_link_texts
    parsed_html.css(%(.card form p.actions a[href="#{admin_consent_terms_path}"])).map { |link| link.text.squish }.select { |text| text == "条件をリセット" }
  end

  def empty_state_reset_link_texts
    parsed_html.css(%(.consent-term-filter-empty-state p.actions a[href="#{admin_consent_terms_path}"])).map { |link| link.text.squish }.select { |text| text == "条件をリセット" }
  end

  def create_consent_term!(attributes = {})
    defaults = {
      title: "同意文面",
      body: "本文",
      version_label: SecureRandom.hex(4),
      consent_scope: "project",
      requirement_timing: "first_view",
      active: true
    }

    ConsentTerm.create!(defaults.merge(attributes))
  end
end