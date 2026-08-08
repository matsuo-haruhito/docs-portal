require "rails_helper"

RSpec.describe MasterSync::RequestProcessor do
  self.use_transactional_tests = false

  before do
    @idempotency_keys = []
    @external_ids = []
  end

  after do
    mappings = ExternalMasterSyncMapping.where(external_id: @external_ids).to_a
    targets = mappings.filter_map(&:sync_target)

    MasterSyncReceipt.where(idempotency_key: @idempotency_keys).delete_all
    ExternalMasterSyncMapping.where(id: mappings.map(&:id)).delete_all
    targets.group_by(&:class).each do |model_class, records|
      model_class.where(id: records.map(&:id)).delete_all
    end
  end

  def processor(idempotency_key:, request_digest:, resource_type: "company", external_id:)
    @idempotency_keys << idempotency_key
    @external_ids << external_id
    described_class.new(
      idempotency_key:,
      request_digest:,
      source_system: "sales-mgt",
      resource_type:,
      external_id:
    )
  end

  def company_payload(name:, source_updated_at:)
    {
      "operation" => "upsert",
      "source_updated_at" => source_updated_at,
      "attributes" => { "name" => name, "active" => true }
    }
  end

  def concurrently(*operations)
    gate = Queue.new
    threads = operations.map do |operation|
      Thread.new do
        Thread.current.report_on_exception = false
        ApplicationRecord.connection_pool.with_connection do
          gate.pop
          operation.call
        end
      end
    end
    operations.size.times { gate << true }
    threads.map(&:value)
  end

  it "同一Idempotency-Keyの同一requestを一度だけ適用して確定responseをreplayする" do
    suffix = SecureRandom.hex(6)
    key = "concurrent-replay-#{suffix}"
    external_id = "company-#{suffix}"
    digest = Digest::SHA256.hexdigest("same-request")
    payload = company_payload(name: "同時同期会社", source_updated_at: "2026-08-06T09:00:00Z")
    processors = 2.times.map do
      processor(idempotency_key: key, request_digest: digest, external_id:)
    end

    responses = concurrently(*processors.map { |instance| -> { instance.call(payload:) } })

    expect(responses.map(&:status).uniq).to eq([200])
    expect(responses.map(&:replayed).sort_by(&:to_s)).to eq([false, true])
    expect(MasterSyncReceipt.where(idempotency_key: key).count).to eq(1)
    mapping = ExternalMasterSyncMapping.find_by!(external_id:)
    expect(mapping.sync_target).to have_attributes(name: "同時同期会社", active: true)
  end

  it "同一Idempotency-Keyの異なるrequestが競合しても一方だけを確定する" do
    suffix = SecureRandom.hex(6)
    key = "concurrent-conflict-#{suffix}"
    external_id = "company-#{suffix}"
    first = processor(
      idempotency_key: key,
      request_digest: Digest::SHA256.hexdigest("first"),
      external_id:
    )
    second = processor(
      idempotency_key: key,
      request_digest: Digest::SHA256.hexdigest("second"),
      external_id:
    )
    first_payload = company_payload(name: "先行候補", source_updated_at: "2026-08-06T09:00:00Z")
    second_payload = company_payload(name: "後行候補", source_updated_at: "2026-08-06T09:01:00Z")

    responses = concurrently(
      -> { first.call(payload: first_payload) },
      -> { second.call(payload: second_payload) }
    )

    expect(responses.map(&:status).sort_by(&:to_s)).to eq([200, :conflict].sort_by(&:to_s))
    expect(MasterSyncReceipt.where(idempotency_key: key).count).to eq(1)
    expect(ExternalMasterSyncMapping.where(external_id:).count).to eq(1)
  end

  it "異なるkeyで同じmappingを更新しても新しいsource_updated_atを最終状態にする" do
    suffix = SecureRandom.hex(6)
    external_id = "company-#{suffix}"
    older = processor(
      idempotency_key: "mapping-older-#{suffix}",
      request_digest: Digest::SHA256.hexdigest("older"),
      external_id:
    )
    newer = processor(
      idempotency_key: "mapping-newer-#{suffix}",
      request_digest: Digest::SHA256.hexdigest("newer"),
      external_id:
    )

    responses = concurrently(
      -> { older.call(payload: company_payload(name: "旧会社", source_updated_at: "2026-08-06T09:00:00Z")) },
      -> { newer.call(payload: company_payload(name: "新会社", source_updated_at: "2026-08-06T10:00:00Z")) }
    )

    expect(responses.map(&:status).uniq).to eq([200])
    mapping = ExternalMasterSyncMapping.find_by!(external_id:)
    expect(mapping.source_updated_at).to eq(Time.zone.parse("2026-08-06T10:00:00Z"))
    expect(mapping.sync_target.name).to eq("新会社")
    expect(MasterSyncReceipt.where(idempotency_key: @idempotency_keys).count).to eq(2)
  end

  it "mapping保存失敗時は作成済みtargetをrollbackし、422 receiptだけを確定する" do
    suffix = SecureRandom.hex(6)
    key = "mapping-rejection-#{suffix}"
    external_id = "company-#{suffix}"
    digest = Digest::SHA256.hexdigest("mapping-rejection")
    instance = processor(idempotency_key: key, request_digest: digest, external_id:)
    mapping = ExternalMasterSyncMapping.new
    allow(mapping).to receive(:update!) do
      mapping.errors.add(:base, "mapping保存失敗")
      raise ActiveRecord::RecordInvalid, mapping
    end
    allow(ExternalMasterSyncMapping).to receive(:new).and_return(mapping)

    expect do
      @response = instance.call(
        payload: company_payload(name: "rollback会社", source_updated_at: "2026-08-06T09:00:00Z")
      )
    end.to change(MasterSyncReceipt, :count).by(1)
      .and change(ExternalMasterSyncMapping, :count).by(0)
      .and change(Company, :count).by(0)

    expect(@response.status).to eq(422)
    expect(MasterSyncReceipt.find_by!(idempotency_key: key)).to have_attributes(response_status: 422)
  end
end
