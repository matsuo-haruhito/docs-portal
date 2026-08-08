require "rails_helper"

RSpec.describe "API internal master syncs", type: :request do
  let(:token) { "master-sync-token" }
  let(:default_headers) do
    {
      "Authorization" => "Bearer #{token}",
      "Idempotency-Key" => "sync-request-1",
      "CONTENT_TYPE" => "application/json"
    }
  end

  before do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("DOCS_PORTAL_SYNC_TOKEN", "").and_return(token)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("READ_ONLY_MAINTENANCE").and_return(nil)
  end

  def endpoint(resource_type:, external_id:, source_system: "sales-mgt")
    "/api/internal/master_syncs/#{source_system}/#{resource_type}/#{external_id}"
  end

  def sync(resource_type:, external_id:, payload:, idempotency_key: "sync-request-1", headers: {})
    put endpoint(resource_type:, external_id:),
      params: payload.to_json,
      headers: default_headers.merge("Idempotency-Key" => idempotency_key).merge(headers)
  end

  it "requires the dedicated bearer token" do
    sync(
      resource_type: "company",
      external_id: "company-1",
      payload: company_payload,
      headers: { "Authorization" => "Bearer invalid" }
    )

    expect(response).to have_http_status(:unauthorized)
    expect(ExternalMasterSyncMapping.count).to eq(0)
    expect(MasterSyncReceipt.count).to eq(0)
  end

  it "requires an idempotency key" do
    sync(
      resource_type: "company",
      external_id: "company-1",
      payload: company_payload,
      headers: { "Idempotency-Key" => "" }
    )

    expect(response).to have_http_status(:bad_request)
    expect(ExternalMasterSyncMapping.count).to eq(0)
    expect(MasterSyncReceipt.count).to eq(0)
  end

  it "creates a company, mapping, and completed receipt atomically" do
    expect do
      sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    end.to change(Company, :count).by(1)
      .and change(ExternalMasterSyncMapping, :count).by(1)
      .and change(MasterSyncReceipt, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(
      "status" => "applied",
      "source_system" => "sales-mgt",
      "resource_type" => "company",
      "external_id" => "company-1"
    )

    company = Company.last
    mapping = ExternalMasterSyncMapping.last
    receipt = MasterSyncReceipt.last

    expect(company).to have_attributes(
      name: "同期会社",
      domain: "sales-mgt-company-1.invalid",
      active: true
    )
    expect(mapping.sync_target).to eq(company)
    expect(mapping.source_attributes).to eq(company_payload.fetch(:attributes).deep_stringify_keys)
    expect(receipt).to have_attributes(
      idempotency_key: "sync-request-1",
      source_system: "sales-mgt",
      resource_type: "company",
      external_id: "company-1",
      response_status: 200
    )
    expect(response.parsed_body["mapping_id"]).to eq(mapping.public_id)
    expect(response.parsed_body["portal_public_id"]).to eq(company.public_id)
    expect(response.parsed_body["portal_url"]).to eq(edit_admin_company_path(company.public_id))
  end

  it "replays a completed response without applying the request twice" do
    sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    original_body = response.parsed_body

    expect do
      sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    end.not_to change { [Company.count, ExternalMasterSyncMapping.count, MasterSyncReceipt.count] }

    expect(response).to have_http_status(:ok)
    expect(response.headers["Idempotency-Replayed"]).to eq("true")
    expect(response.parsed_body).to eq(original_body)
  end

  it "rejects reuse of an idempotency key with a different request digest" do
    sync(resource_type: "company", external_id: "company-1", payload: company_payload)

    changed_payload = company_payload.deep_merge(attributes: { name: "別会社" })
    expect do
      sync(resource_type: "company", external_id: "company-1", payload: changed_payload)
    end.not_to change { [Company.last.name, ExternalMasterSyncMapping.count, MasterSyncReceipt.count] }

    expect(response).to have_http_status(:conflict)
    expect(response.headers["Idempotency-Replayed"]).to be_nil
  end

  it "treats an older source update as a stale no-op" do
    sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    mapping = ExternalMasterSyncMapping.last

    stale_payload = company_payload.deep_merge(
      source_updated_at: "2026-08-06T08:59:59Z",
      attributes: { name: "古い会社名" }
    )
    sync(
      resource_type: "company",
      external_id: "company-1",
      payload: stale_payload,
      idempotency_key: "sync-request-stale"
    )

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("stale")
    expect(mapping.reload.source_updated_at).to eq(Time.zone.parse("2026-08-06T09:00:00Z"))
    expect(mapping.source_attributes).to eq(company_payload.fetch(:attributes).deep_stringify_keys)
    expect(mapping.sync_target.name).to eq("同期会社")
    expect(MasterSyncReceipt.find_by!(idempotency_key: "sync-request-stale").response_status).to eq(200)
  end

  it "archives an existing target without deleting it" do
    sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    company = Company.last

    archive_payload = {
      operation: "archive",
      source_updated_at: "2026-08-06T10:00:00Z",
      attributes: { reason: "source_archived" }
    }
    expect do
      sync(
        resource_type: "company",
        external_id: "company-1",
        payload: archive_payload,
        idempotency_key: "sync-request-archive"
      )
    end.not_to change(Company, :count)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("archived")
    expect(company.reload.active).to eq(false)
    expect(ExternalMasterSyncMapping.last.source_attributes).to eq("reason" => "source_archived")
  end

  it "revokes external project access when its synced company is archived" do
    sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    company = Company.last
    sync(
      resource_type: "project",
      external_id: "project-1",
      idempotency_key: "sync-project-for-archive",
      payload: {
        operation: "upsert",
        source_updated_at: "2026-08-06T09:01:00Z",
        attributes: {
          project_number: "SM-PJ-ARCHIVE",
          name: "会社停止対象案件",
          company_external_id: "company-1"
        }
      }
    )
    project = Project.find_by!(code: "SM-PJ-ARCHIVE")
    viewer = create(:user, :external, company:)
    create(:project_membership, project:, user: viewer)

    expect(project.viewable_by?(viewer)).to be(true)
    expect(Project.accessible_to(viewer)).to include(project)

    sync(
      resource_type: "company",
      external_id: "company-1",
      idempotency_key: "sync-company-archive-access",
      payload: {
        operation: "archive",
        source_updated_at: "2026-08-06T10:00:00Z",
        attributes: { reason: "source_archived" }
      }
    )

    expect(project.reload.viewable_by?(viewer)).to be(false)
    expect(Project.accessible_to(viewer)).not_to include(project)
  end

  it "records an archive tombstone when the source target was never imported" do
    payload = {
      operation: "archive",
      source_updated_at: "2026-08-06T10:00:00Z",
      attributes: {}
    }

    expect do
      sync(resource_type: "company", external_id: "unknown-company", payload:)
    end.to change(ExternalMasterSyncMapping, :count).by(1)
      .and change(MasterSyncReceipt, :count).by(1)
      .and change(Company, :count).by(0)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("archived")
    expect(ExternalMasterSyncMapping.last.sync_target).to be_nil
  end

  it "resolves company and project mappings when importing projects and documents" do
    sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    company = Company.last

    project_payload = {
      operation: "upsert",
      source_updated_at: "2026-08-06T09:01:00Z",
      attributes: {
        project_number: "SM-PJ-001",
        name: "同期案件",
        notes: "案件メモ",
        company_external_id: "company-1"
      }
    }
    sync(
      resource_type: "project",
      external_id: "project-1",
      payload: project_payload,
      idempotency_key: "sync-project-1"
    )

    expect(response).to have_http_status(:ok)
    project = Project.last
    expect(project).to have_attributes(code: "SM-PJ-001", name: "同期案件", company: company, active: true)

    document_payload = {
      operation: "upsert",
      source_updated_at: "2026-08-06T09:02:00Z",
      attributes: {
        file_name: "同期文書.pdf",
        slug: "synced-document",
        project_external_id: "project-1",
        total_amount: 12_345
      }
    }
    sync(
      resource_type: "document",
      external_id: "document-1",
      payload: document_payload,
      idempotency_key: "sync-document-1"
    )

    expect(response).to have_http_status(:ok)
    document = Document.last
    expect(document).to have_attributes(title: "同期文書.pdf", slug: "synced-document", project: project)
    expect(document.document_versions).to be_empty
    expect(DocumentFile.where(document_version_id: document.document_version_ids)).to be_empty
    expect(ExternalMasterSyncMapping.find_by!(resource_type: "document").source_attributes)
      .to eq(document_payload.fetch(:attributes).deep_stringify_keys)
  end

  it "retries a missing parent mapping with the same idempotency key after the parent arrives" do
    document_payload = {
      operation: "upsert",
      source_updated_at: "2026-08-06T09:02:00Z",
      attributes: {
        title: "親待ち文書",
        slug: "waiting-for-project",
        project_external_id: "project-later"
      }
    }

    expect do
      sync(
        resource_type: "document",
        external_id: "document-waiting",
        payload: document_payload,
        idempotency_key: "sync-document-waiting"
      )
    end.not_to change { [Document.count, ExternalMasterSyncMapping.count, MasterSyncReceipt.count] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include(
      "status" => "deferred",
      "error_code" => "missing_dependency",
      "retryable" => true
    )
    expect(response.headers["Idempotency-Replayed"]).to be_nil

    sync(
      resource_type: "project",
      external_id: "project-later",
      payload: {
        operation: "upsert",
        source_updated_at: "2026-08-06T09:01:00Z",
        attributes: { project_number: "SM-PJ-LATER", name: "後着案件" }
      },
      idempotency_key: "sync-project-later"
    )

    expect do
      sync(
        resource_type: "document",
        external_id: "document-waiting",
        payload: document_payload,
        idempotency_key: "sync-document-waiting"
      )
    end.to change(Document, :count).by(1)
      .and change(MasterSyncReceipt, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Idempotency-Replayed"]).to be_nil
    expect(Document.last.project).to eq(Project.find_by!(code: "SM-PJ-LATER"))
  end

  it "persists deterministic validation rejections for replay" do
    invalid_payload = {
      operation: "upsert",
      source_updated_at: "2026-08-06T09:00:00Z",
      attributes: { project_number: "SM-PJ-001" }
    }

    expect do
      sync(resource_type: "project", external_id: "project-1", payload: invalid_payload)
    end.to change(MasterSyncReceipt, :count).by(1)
      .and change(Project, :count).by(0)
      .and change(ExternalMasterSyncMapping, :count).by(0)

    expect(response).to have_http_status(:unprocessable_content)
    receipt = MasterSyncReceipt.last
    expect(receipt.response_status).to eq(422)

    sync(resource_type: "project", external_id: "project-1", payload: invalid_payload)
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.headers["Idempotency-Replayed"]).to eq("true")
    expect(MasterSyncReceipt.count).to eq(1)
  end

  it "accepts only JSON booleans for active and replays deterministic type errors" do
    inactive_payload = company_payload.deep_merge(attributes: { active: false })
    sync(
      resource_type: "company",
      external_id: "company-inactive",
      payload: inactive_payload,
      idempotency_key: "sync-company-inactive"
    )

    expect(response).to have_http_status(:ok)
    expect(Company.find_by!(name: "同期会社")).not_to be_active

    ["true", "false", 1, 0, nil, [], {}].each_with_index do |invalid_value, index|
      invalid_payload = company_payload.deep_merge(attributes: { active: invalid_value })
      idempotency_key = "sync-company-invalid-active-#{index}"

      expect do
        sync(
          resource_type: "company",
          external_id: "company-invalid-#{index}",
          payload: invalid_payload,
          idempotency_key:
        )
      end.to change(MasterSyncReceipt, :count).by(1)
        .and change(Company, :count).by(0)
        .and change(ExternalMasterSyncMapping, :count).by(0)

      expect(response).to have_http_status(:unprocessable_content)
      receipt_count = MasterSyncReceipt.count

      sync(
        resource_type: "company",
        external_id: "company-invalid-#{index}",
        payload: invalid_payload,
        idempotency_key:
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.headers["Idempotency-Replayed"]).to eq("true")
      expect(MasterSyncReceipt.count).to eq(receipt_count)
    end
  end

  it "rejects unsupported resource types before creating a receipt or target" do
    unsupported_payload = company_payload

    expect do
      sync(
        resource_type: "unknown",
        external_id: "unknown-1",
        payload: unsupported_payload,
        idempotency_key: "sync-unsupported"
      )
    end.not_to change { [Company.count, Project.count, Document.count, ExternalMasterSyncMapping.count, MasterSyncReceipt.count] }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include(
      "status" => "rejected",
      "error_code" => "unsupported_resource_type",
      "retryable" => false
    )
    expect(response.headers["Idempotency-Replayed"]).to be_nil
  end

  it "replays completed receipts during read-only maintenance but blocks new changes" do
    sync(resource_type: "company", external_id: "company-1", payload: company_payload)
    original_body = response.parsed_body
    allow(ENV).to receive(:[]).with("READ_ONLY_MAINTENANCE").and_return("true")

    sync(resource_type: "company", external_id: "company-1", payload: company_payload)

    expect(response).to have_http_status(:ok)
    expect(response.headers["Idempotency-Replayed"]).to eq("true")
    expect(response.parsed_body).to eq(original_body)

    expect do
      sync(
        resource_type: "company",
        external_id: "company-2",
        payload: company_payload,
        idempotency_key: "sync-request-maintenance"
      )
    end.not_to change { [Company.count, ExternalMasterSyncMapping.count, MasterSyncReceipt.count] }

    expect(response).to have_http_status(:service_unavailable)
  end

  it "rejects request bodies larger than one MiB before persistence" do
    oversized_payload = company_payload.deep_merge(attributes: { notes: "x" * (1.megabyte + 1) })

    sync(resource_type: "company", external_id: "company-1", payload: oversized_payload)

    expect(response).to have_http_status(:bad_request)
    expect(ExternalMasterSyncMapping.count).to eq(0)
    expect(MasterSyncReceipt.count).to eq(0)
  end

  def company_payload
    {
      operation: "upsert",
      source_updated_at: "2026-08-06T09:00:00Z",
      attributes: {
        name: "同期会社",
        code: "CUSTOMER-001",
        short_name: "同期",
        active: true
      }
    }
  end
end
