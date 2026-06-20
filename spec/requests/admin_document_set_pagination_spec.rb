require "csv"
require "rails_helper"

RSpec.describe "Admin document set pagination", type: :request do
  let(:admin) { create(:user, :admin) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  def table_text
    parsed_html.css("tbody").text.squish
  end

  def link_href(text)
    parsed_html.css("a[href]").find { |link| link.text.squish == text }&.[]("href")
  end

  def listed_document_set_names
    parsed_html.css('tbody td[data-rails-table-preferences-column-key="name"]').map do |node|
      node.text.squish
    end
  end

  def document_set_form_action
    parsed_html.css("form[action]").find do |node|
      node.at_css('input[name="document_set[name]"]')
    end&.[]("action")
  end

  def create_paged_document_sets(prefix:, count:, set_type: :delivery, visibility_policy: :restricted_external)
    project = create(:project, code: "#{prefix}-PJ", name: "#{prefix} Project")

    Array.new(count) do |index|
      create(
        :document_set,
        project:,
        name: format("%<prefix>s Set %<index>02d", prefix:, index:),
        set_type:,
        visibility_policy:,
        sort_order: index
      )
    end
  end

  it "paginates filtered document sets while keeping filter params on page links" do
    matching_sets = create_paged_document_sets(prefix: "DSET-PAGE", count: 3)
    create_paged_document_sets(prefix: "DSET-OTHER", count: 1, set_type: :design, visibility_policy: :public_with_login)

    sign_in_as(admin)

    get admin_document_sets_path, params: {
      q: "DSET-PAGE",
      set_type: "delivery",
      visibility_policy: "restricted_external",
      per_page: 2
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("検索結果: 3件")
    expect(page_text).to include("表示中: 1-2件 / 3件")
    expect(listed_document_set_names).to eq(["DSET-PAGE Set 00", "DSET-PAGE Set 01"])
    expect(table_text).not_to include("DSET-PAGE Set 02", "DSET-OTHER Set 00")
    expect(link_href("次へ")).to include(
      "q=DSET-PAGE",
      "set_type=delivery",
      "visibility_policy=restricted_external",
      "per_page=2",
      "page=2"
    )

    get admin_document_sets_path, params: {
      q: "DSET-PAGE",
      set_type: "delivery",
      visibility_policy: "restricted_external",
      per_page: 2,
      page: 2
    }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 3-3件 / 3件")
    expect(listed_document_set_names).to eq(["DSET-PAGE Set 02"])
    expect(link_href("前へ")).to include(
      "q=DSET-PAGE",
      "set_type=delivery",
      "visibility_policy=restricted_external",
      "per_page=2",
      "page=1"
    )

    get admin_document_sets_path, params: { q: "DSET-PAGE", per_page: 0, page: -1 }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("表示中: 1-3件 / 3件")
    expect(listed_document_set_names).to eq(matching_sets.map(&:name))
  end

  it "keeps CSV export on the full filtered set even when page params are present" do
    matching_sets = create_paged_document_sets(prefix: "DSET-CSV", count: 3)
    create_paged_document_sets(prefix: "DSET-NOCSV", count: 1)

    sign_in_as(admin)

    get admin_document_sets_path(format: :csv), params: { q: "DSET-CSV", per_page: 1, page: 2 }

    expect(response).to have_http_status(:ok)
    csv = CSV.parse(response.body, headers: true)
    expect(csv["文書セット名"]).to eq(matching_sets.map(&:name))
    expect(csv["文書セット名"]).not_to include("DSET-NOCSV Set 00")
  end

  it "keeps the current filter context on invalid create rerender without leaking page params into the form action" do
    project = create(:project, code: "DSET-FORM", name: "DSET-FORM Project")
    create(
      :document_set,
      project:,
      name: "DSET-FORM Set 00",
      set_type: :delivery,
      visibility_policy: :internal_only
    )

    sign_in_as(admin)

    post admin_document_sets_path(q: "DSET-FORM", set_type: "delivery", visibility_policy: "internal_only", per_page: 2), params: {
      document_set: {
        project_id: project.id,
        name: "",
        description: "filtered create",
        set_type: "delivery",
        visibility_policy: "internal_only",
        sort_order: 4
      },
      document_set_items: {}
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(page_text).to include("検索結果: 1件")
    expect(listed_document_set_names).to eq(["DSET-FORM Set 00"])
    expect(document_set_form_action).to eq(
      admin_document_sets_path(q: "DSET-FORM", set_type: "delivery", visibility_policy: "internal_only")
    )
  end
end
