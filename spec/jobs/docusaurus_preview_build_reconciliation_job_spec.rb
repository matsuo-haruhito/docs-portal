require "rails_helper"

RSpec.describe DocusaurusPreviewBuildReconciliationJob, type: :job do
  include ActiveJob::TestHelper

  before do
    clear_enqueued_jobs
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(true)
    allow(DocusaurusPreviewArtifactInstaller).to receive(:installed_artifact_for).and_return(nil)
  end

  after do
    clear_enqueued_jobs
    DocumentVersion.find_each { |version| FileUtils.rm_rf(version.site_root_absolute_path) }
  end

  def buildable_version(source_path: "docs/guide.md")
    create(:document_version).tap do |version|
      version.assign_source_path_metadata!(source_path:, snapshot_kind: "received_markdown")
      version.save!
    end
  end

  it "queues a markdown version that was never requested" do
    version = buildable_version

    expect { described_class.perform_now }
      .to have_enqueued_job(DocusaurusPreviewBuildJob).with(version.id)

    expect(version.reload).to be_preview_queued
    expect(version.preview_build_reconciled_at).to be_present
  end

  it "recovers a queued version whose worker never started and consumes the bounded recovery budget" do
    version = buildable_version
    version.mark_preview_build_queued!(at: 11.minutes.ago)

    expect { described_class.perform_now }
      .to have_enqueued_job(DocusaurusPreviewBuildJob).with(version.id)

    expect(version.reload).to be_preview_queued
    expect(version.preview_build_enqueued_at).to be > 1.minute.ago
    expect(version.preview_build_attempt_count).to eq(1)
  end

  it "abandons a repeatedly stale queued version instead of enqueueing forever" do
    version = buildable_version
    version.update!(
      preview_build_status: :preview_queued,
      preview_build_attempt_count: DocumentVersion::PREVIEW_BUILD_MAX_ATTEMPTS - 1,
      preview_build_enqueued_at: 11.minutes.ago
    )

    expect { described_class.perform_now }
      .not_to have_enqueued_job(DocusaurusPreviewBuildJob)

    expect(version.reload).to be_preview_abandoned
    expect(version.preview_build_attempt_count).to eq(DocumentVersion::PREVIEW_BUILD_MAX_ATTEMPTS)
  end

  it "replaces a stale running claim without consuming another attempt before execution" do
    version = buildable_version
    version.mark_preview_build_queued!(at: 22.minutes.ago)
    stale_token = version.claim_preview_build!(at: 21.minutes.ago)

    expect { described_class.perform_now }
      .to have_enqueued_job(DocusaurusPreviewBuildJob).with(version.id)

    expect(version.reload).to be_preview_queued
    expect(version.preview_build_attempt_count).to eq(1)
    expect(version.preview_build_claim_token).to be_nil
    expect(version.preview_build_claim_token).not_to eq(stale_token)
  end

  it "queues a failed version only after its persistent retry time" do
    version = buildable_version
    now = 2.minutes.ago
    version.mark_preview_build_queued!(at: now)
    claim_token = version.claim_preview_build!(at: now)
    version.mark_preview_build_failed!("renderer failed", claim_token:, at: now)

    expect { described_class.perform_now }
      .to have_enqueued_job(DocusaurusPreviewBuildJob).with(version.id)
    expect(version.reload).to be_preview_queued
  end

  it "abandons an exhausted failed version instead of enqueueing forever" do
    version = buildable_version
    version.update!(
      preview_build_status: :preview_failed,
      preview_build_attempt_count: DocumentVersion::PREVIEW_BUILD_MAX_ATTEMPTS,
      preview_build_retry_at: 1.minute.ago
    )

    expect { described_class.perform_now }
      .not_to have_enqueued_job(DocusaurusPreviewBuildJob)

    expect(version.reload).to be_preview_abandoned
    expect(version.preview_build_retry_at).to be_nil
  end

  it "requeues a succeeded row when no installed artifact exists" do
    version = buildable_version
    version.update!(
      preview_build_status: :preview_succeeded,
      markdown_entry_path: version.source_relative_path,
      site_build_path: "docs/guide",
      preview_build_completed_at: 1.hour.ago
    )

    expect { described_class.perform_now }
      .to have_enqueued_job(DocusaurusPreviewBuildJob).with(version.id)
    expect(version.reload).to be_preview_queued
  end

  it "repairs database state from a matching installed artifact without rebuilding" do
    version = buildable_version
    claim_token = SecureRandom.uuid
    version.update!(
      preview_build_status: :preview_running,
      preview_build_attempt_count: 1,
      preview_build_claim_token: claim_token,
      preview_build_started_at: 1.minute.ago
    )
    artifact = DocusaurusPreviewArtifactInstaller::Artifact.new(
      site_path: "docs/guide",
      claim_token:,
      source_path: version.source_relative_path,
      marker_path: version.site_root_absolute_path.join(DocusaurusPreviewArtifactInstaller::MARKER_FILE_NAME)
    )
    allow(DocusaurusPreviewArtifactInstaller).to receive(:installed_artifact_for).and_return(artifact)

    expect { described_class.perform_now }
      .not_to have_enqueued_job(DocusaurusPreviewBuildJob)

    expect(version.reload).to have_attributes(
      preview_build_status: "preview_succeeded",
      markdown_entry_path: version.source_relative_path,
      site_build_path: "docs/guide",
      preview_build_claim_token: nil
    )
    expect(version.preview_build_reconciled_at).to be_present
  end

  it "processes only the requested bounded batch" do
    first = buildable_version(source_path: "docs/first.md")
    second = buildable_version(source_path: "docs/second.md")

    described_class.perform_now(limit: 1)

    expect([first.reload, second.reload].count(&:preview_queued?)).to eq(1)
    expect([first, second].count { _1.preview_build_reconciled_at.present? }).to eq(1)
  end

  it "does not inspect, enqueue, or mutate versions while the reliability rollout gate is off" do
    version = buildable_version
    version.mark_preview_build_queued!(at: 11.minutes.ago)
    original_attributes = version.attributes.slice(
      "preview_build_status",
      "preview_build_attempt_count",
      "preview_build_enqueued_at",
      "preview_build_started_at",
      "preview_build_retry_at",
      "preview_build_claim_token",
      "preview_build_reconciled_at",
      "updated_at"
    )
    allow(JobReliability::RolloutGate).to receive(:enabled?).and_return(false)

    expect { described_class.perform_now }
      .not_to have_enqueued_job(DocusaurusPreviewBuildJob)

    expect(DocusaurusPreviewArtifactInstaller).not_to have_received(:installed_artifact_for)
    expect(version.reload.attributes.slice(*original_attributes.keys)).to eq(original_attributes)
  end

  it "does not inspect, enqueue, or mutate versions during read-only maintenance" do
    version = buildable_version
    version.mark_preview_build_queued!(at: 11.minutes.ago)
    original_attributes = version.attributes.slice(
      "preview_build_status",
      "preview_build_attempt_count",
      "preview_build_enqueued_at",
      "preview_build_started_at",
      "preview_build_retry_at",
      "preview_build_claim_token",
      "preview_build_reconciled_at",
      "updated_at"
    )
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with("READ_ONLY_MAINTENANCE", nil).and_return("true")

    expect { described_class.perform_now }
      .not_to have_enqueued_job(DocusaurusPreviewBuildJob)

    expect(DocusaurusPreviewArtifactInstaller).not_to have_received(:installed_artifact_for)
    expect(version.reload.attributes.slice(*original_attributes.keys)).to eq(original_attributes)
  end
end
