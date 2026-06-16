require "rails_helper"

RSpec.describe "Accessible documents empty state copy", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project, name: "Alpha Project", code: "ALPHA") }
  let(:user) { create(:user, :external, company:) }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def page_text
    parsed_html.text.squish
  end

  before do
    create(:project_membership, project:, user:)
  end

  it "does not describe the no-filter empty state as a filter miss" do
    sign_in_as(user)

    get documents_path

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("現在閲覧できる文書はありません")
    expect(page_text).to include("閲覧可能な文書がまだ登録されていないか、現在のアカウントに閲覧権限が付与されていない可能性があります。")
    expect(page_text).to include("必要な文書が表示されない場合は、担当者へ閲覧権限の確認を依頼してください。")
    expect(page_text).not_to include("絞り込み条件に一致する閲覧可能な文書がありませんでした")
    expect(parsed_html.css(".empty-state a").map { _1.text.squish }).not_to include("条件をクリア")
  end

  it "keeps active filter details and the clear action in the filtered empty state" do
    document = create(:document, project:, title: "Published Manual", slug: "published-manual", category: :manual, visibility_policy: :restricted_external)
    create(:document_permission, document:, company:, access_level: :view)
    sign_in_as(user)

    get documents_path, params: { category: "contract", has_diagram: "1" }

    expect(response).to have_http_status(:ok)
    expect(page_text).to include("条件に一致する文書はありません")
    expect(page_text).to include("現在の絞り込み条件に一致する閲覧可能な文書がありませんでした")
    expect(page_text).to include("カテゴリ: 契約")
    expect(page_text).to include("図あり")
    expect(parsed_html.css(".empty-state a").map { _1.text.squish }).to include("条件をクリア")
  end
end
