require "rails_helper"

RSpec.describe "DocumentVersion preview build status" do
  let(:version) { create(:document_version) }

  it "marks preview build queued" do
    version.mark_preview_build_queued!

    expect(version).to be_preview_queued
    expect(version.preview_build_error_message).to be_nil
    expect(version.preview_build_attempted_at).to be_present
    expect(version.preview_build_completed_at).to be_nil
  end

  it "marks preview build running" do
    version.mark_preview_build_running!

    expect(version).to be_preview_running
    expect(version.preview_build_error_message).to be_nil
    expect(version.preview_build_attempted_at).to be_present
    expect(version.preview_build_completed_at).to be_nil
  end

  it "marks preview build succeeded" do
    version.update!(preview_build_error_message: "old error")

    version.mark_preview_build_succeeded!

    expect(version).to be_preview_succeeded
    expect(version.preview_build_error_message).to be_nil
    expect(version.preview_build_completed_at).to be_present
  end

  it "marks preview build failed and truncates long errors" do
    version.mark_preview_build_failed!("x" * 3_000)

    expect(version).to be_preview_failed
    expect(version.preview_build_error_message.length).to be <= 2_000
    expect(version.preview_build_completed_at).to be_present
  end
end
