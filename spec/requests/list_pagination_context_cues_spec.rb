require "rails_helper"

RSpec.describe "list pagination context cues", type: :request do
  def view_source(path)
    Rails.root.join(path).read
  end

  it "keeps admin user and company pagination labels tied to filtered page params" do
    user_source = view_source("app/views/admin/users/index.html.slim")
    company_source = view_source("app/views/admin/companies/index.html.slim")

    expect(user_source).to include('previous_user_page_label = "ユーザー一覧の#{previous_user_page}ページ目へ（現在の検索条件を保持）"')
    expect(user_source).to include("admin_users_path(@user_page_params.merge(page: previous_user_page))")
    expect(user_source).to include("admin_users_path(@user_page_params.merge(page: next_user_page))")
    expect(user_source).to include("aria: { label: previous_user_page_label }, title: previous_user_page_label")
    expect(user_source).to include("aria: { label: next_user_page_label }, title: next_user_page_label")

    expect(company_source).to include('previous_company_page_label = "会社一覧の#{previous_company_page}ページ目へ（現在の検索条件を保持）"')
    expect(company_source).to include("admin_companies_path(@company_page_params.merge(page: previous_company_page))")
    expect(company_source).to include("admin_companies_path(@company_page_params.merge(page: next_company_page))")
    expect(company_source).to include("aria: { label: previous_company_page_label }, title: previous_company_page_label")
    expect(company_source).to include("aria: { label: next_company_page_label }, title: next_company_page_label")
  end

  it "keeps access request pagination labels tied to current filter params" do
    source = view_source("app/views/access_requests/index.html.slim")

    expect(source).to include('previous_access_request_page_label = "アクセス申請一覧の#{previous_access_request_page}ページ目へ（現在の検索条件を保持）"')
    expect(source).to include("access_requests_path(page_link_params.merge(page: previous_access_request_page))")
    expect(source).to include("access_requests_path(page_link_params.merge(page: next_access_request_page))")
    expect(source).to include("aria: { label: previous_access_request_page_label }, title: previous_access_request_page_label")
    expect(source).to include("aria: { label: next_access_request_page_label }, title: next_access_request_page_label")
  end

  it "keeps admin document pagination labels tied to current filter params" do
    source = view_source("app/views/admin/documents/index.html.slim")

    expect(source).to include('previous_document_page_label = "文書マスタ一覧の#{previous_document_page}ページ目へ（現在の検索条件を保持）"')
    expect(source).to include("admin_documents_path(@document_page_params.merge(page: previous_document_page))")
    expect(source).to include("admin_documents_path(@document_page_params.merge(page: next_document_page))")
    expect(source).to include("aria: { label: previous_document_page_label }, title: previous_document_page_label")
    expect(source).to include("aria: { label: next_document_page_label }, title: next_document_page_label")
  end
end
