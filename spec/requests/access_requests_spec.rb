# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Access requests", type: :request do
  let(:user) { create(:user) }
  let(:other_user) { create(:user, email: "other@example.com") }
  let(:project) { create(:project, code: "req-project", name: "Request Project") }
  let(:document) { create(:document, project: project, title: "Request Document") }
  let(:file) { create(:document_file, document: document, file_name: "request.pdf") }

  def parsed_html
    Capybara.string(response.body)
  end

  def page_text
    parsed_html.text
  end

  describe "POST /access_requests" do
    it "creates a pending access request for a document file" do
      sign_in_as(user)

      expect do
        post access_requests_path, params: {
          access_request: {
            requestable_gid: file.to_global_id.to_s,
            requested_access_level: "download",
            reason: "Need this file for the release review."
          }
        }
      end.to change(AccessRequest, :count).by(1)

      access_request = AccessRequest.last
      expect(access_request.requester).to eq(user)
      expect(access_request.requestable).to eq(file)
      expect(access_request.requested_access_level).to eq("download")
      expect(access_request.reason).to eq("Need this file for the release review.")
      expect(response).to redirect_to(access_requests_path)
      follow_redirect!
      expect(response.body).to include("アクセス申請を送信しました。")
    end

    it "accepts Japanese access request reasons" do
      sign_in_as(user)

      expect do
        post access_requests_path, params: {
          access_request: {
            requestable_gid: file.to_global_id.to_s,
            requested_access_level: "download",
            reason: "リリース確認のため資料を確認したいです。"
          }
        }
      end.to change(AccessRequest, :count).by(1)

      access_request = AccessRequest.last
      expect(access_request.reason).to eq("リリース確認のため資料を確認したいです。")
      expect(response).to redirect_to(access_requests_path)
      follow_redirect!
      expect(response.body).to include("アクセス申請を送信しました。")
    end

    it "keeps access requests scoped to the signed in user" do
      sign_in_as(user)

      post access_requests_path, params: {
        access_request: {
          requestable_gid: file.to_global_id.to_s,
          requested_access_level: "download",
          reason: "Need this file for the release review."
        }
      }

      expect(AccessRequest.last.requester).to eq(user)
    end

    it "rejects duplicate pending requests" do
      create(:access_request, requester: user, requestable: file, requested_access_level: :download)
      sign_in_as(user)

      expect do
        post access_requests_path, params: {
          access_request: {
            requestable_gid: file.to_global_id.to_s,
            requested_access_level: "download",
            reason: "Need this file for the release review."
          }
        }
      end.not_to change(AccessRequest, :count)

      expect(response.body).to include("この対象への同じ権限レベルの申請はすでに保留中です。")
    end
  end

  describe "GET /access_requests" do
    it "shows the current user's requests" do
      create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "mine")
      create(:access_request, requester: other_user, requestable: file, requested_access_level: :download, reason: "other")
      sign_in_as(user)

      get access_requests_path

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("mine")
      expect(page_text).not_to include("other")
    end

    it "lets the requester cancel a pending request" do
      access_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download)
      sign_in_as(user)

      expect do
        patch cancel_access_request_path(access_request)
      end.to change { access_request.reload.status }.from("pending").to("cancelled")

      expect(response).to redirect_to(access_requests_path)
    end

    it "preserves current list filters after cancellation" do
      access_request = create(:access_request, requester: user, requestable: file, requested_access_level: :download)
      sign_in_as(user)

      patch cancel_access_request_path(access_request), params: {
        q: "request",
        status: "pending",
        requested_access_level: "download",
        requestable_type: "DocumentFile"
      }

      expect(response).to redirect_to(access_requests_path(q: "request", status: "pending", requested_access_level: "download", requestable_type: "DocumentFile"))
    end

    it "filters the current user's requests by status and query" do
      create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "needle review")
      create(:access_request, requester: user, requestable: document, requested_access_level: :read, reason: "needle approved", status: :approved)
      create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "other pending")
      sign_in_as(user)

      get access_requests_path, params: { q: "needle", status: "pending" }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("needle review")
      expect(page_text).not_to include("needle approved")
      expect(page_text).not_to include("other pending")
      expect(page_text).to include("申請中 1件 / 承認済み 1件 / 却下 0件 / 取消済み 0件")
    end

    it "normalizes oversized queries and ignores invalid filters" do
      create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "bounded")
      sign_in_as(user)

      get access_requests_path, params: {
        q: "bounded" + ("x" * 200),
        status: "unknown",
        requested_access_level: "all",
        requestable_type: "invalid"
      }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("bounded")
      expect(page_text).to include("申請中 1件 / 承認済み 0件 / 却下 0件 / 取消済み 0件")
    end

    it "filters the current user's requests by access level and requestable type" do
      create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "file download")
      create(:access_request, requester: user, requestable: document, requested_access_level: :read, reason: "document read")
      sign_in_as(user)

      get access_requests_path, params: { requested_access_level: "download", requestable_type: "DocumentFile" }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("file download")
      expect(page_text).not_to include("document read")
    end

    it "bounds query result rows while keeping filtered status counts readable" do
      sign_in_as(user)

      101.times do |index|
        create(
          :access_request,
          requester: user,
          requestable: file,
          requested_access_level: :download,
          status: :cancelled,
          cancelled_at: Time.current,
          reason: format("bounded request %03d", index + 1)
        )
      end

      get access_requests_path, params: {
        q: "bounded",
        status: :cancelled,
        requested_access_level: :download,
        requestable_type: "DocumentFile"
      }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("申請中 0件 / 承認済み 0件 / 却下 0件 / 取消済み 101件")
      expect(page_text).to include("表示件数: 101件中100件を新しい順で表示しています。")
      expect(page_text).to include("条件を追加すると目的の申請を探しやすくなります。")
      expect(parsed_html.css("tbody tr").size).to eq(AccessRequestsController::ACCESS_REQUEST_LIST_LIMIT)
      expect(page_text).to include("bounded request 101")
      expect(page_text).not_to include("bounded request 001")
    end

    it "shows localized filter labels for active request filters" do
      create(:access_request, requester: user, requestable: file, requested_access_level: :download, reason: "localized")
      sign_in_as(user)

      get access_requests_path, params: { status: "pending", requested_access_level: "download", requestable_type: "DocumentFile" }

      expect(response).to have_http_status(:ok)
      expect(page_text).to include("表示中: ステータス: 申請中 / 権限: ダウンロード / 対象: ファイル")
      expect(page_text).not_to include("DocumentFile")
    end

    it "shows request buttons only for resources without a pending request" do
      pending_file = create(:document_file, document: document, file_name: "pending.pdf")
      available_file = create(:document_file, document: document, file_name: "available.pdf")
      create(:access_request, requester: user, requestable: pending_file, requested_access_level: :download)
      sign_in_as(user)

      get project_document_path(project, document)

      expect(response).to have_http_status(:ok)
      expect(parsed_html).to have_button("申請中", disabled: true)
      expect(parsed_html).to have_button("アクセス申請")
      expect(response.body).to include(available_file.to_global_id.to_s)
      expect(response.body).not_to include(pending_file.to_global_id.to_s)
    end
  end
end
