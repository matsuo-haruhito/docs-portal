require "rails_helper"

RSpec.describe "Read confirmations", type: :request do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:user) { create(:user, :external, company:) }
  let(:document) { create(:document, project:, title: "Manual", slug: "manual", visibility_policy: :restricted_external) }

  around do |example|
    original_value = ENV.fetch("READ_ONLY_MAINTENANCE", nil)
    example.run
  ensure
    if original_value.nil?
      ENV.delete("READ_ONLY_MAINTENANCE")
    else
      ENV["READ_ONLY_MAINTENANCE"] = original_value
    end
  end

  before do
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
  end

  it "creates a read confirmation for a readable document" do
    sign_in_as(user)

    expect do
      post read_confirmations_path, params: {
        read_confirmation: { document_id: document.public_id }
      }
    end.to change(ReadConfirmation, :count).by(1)

    confirmation = ReadConfirmation.last
    expect(confirmation.user).to eq(user)
    expect(confirmation.document).to eq(document)
    expect(confirmation.document_version).to eq(document.latest_version)
    expect(confirmation.confirmed_at).to be_present
    expect(response).to redirect_to(root_path)
  end

  it "updates an existing confirmation instead of duplicating it" do
    confirmation = create(:read_confirmation, user:, document:, confirmed_at: 2.days.ago)
    sign_in_as(user)

    expect do
      post read_confirmations_path, params: {
        read_confirmation: { document_id: document.public_id }
      }
    end.not_to change(ReadConfirmation, :count)

    expect(confirmation.reload.confirmed_at).to be > 1.day.ago
  end

  it "does not create or update a read confirmation during read-only maintenance" do
    ENV["READ_ONLY_MAINTENANCE"] = "true"
    confirmation = create(:read_confirmation, user:, document:, confirmed_at: 2.days.ago)
    original_confirmed_at = confirmation.confirmed_at
    sign_in_as(user)

    expect do
      post read_confirmations_path, params: {
        read_confirmation: { document_id: document.public_id }
      }
    end.not_to change(ReadConfirmation, :count)

    expect(confirmation.reload.confirmed_at).to eq(original_confirmed_at)
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("メンテナンス中のため既読確認の変更は停止しています")
  end

  it "does not create a confirmation for an unreadable document" do
    document.update!(visibility_policy: :internal_only)
    sign_in_as(user)

    expect do
      post read_confirmations_path, params: {
        read_confirmation: { document_id: document.public_id }
      }
    end.not_to change(ReadConfirmation, :count)

    expect(response).to have_http_status(:forbidden)
  end

  it "destroys the user's read confirmation" do
    confirmation = create(:read_confirmation, user:, document:)
    sign_in_as(user)

    expect do
      delete read_confirmation_path(confirmation)
    end.to change(ReadConfirmation, :count).by(-1)
  end

  it "does not destroy a read confirmation during read-only maintenance" do
    ENV["READ_ONLY_MAINTENANCE"] = "true"
    confirmation = create(:read_confirmation, user:, document:)
    sign_in_as(user)

    expect do
      delete read_confirmation_path(confirmation)
    end.not_to change(ReadConfirmation, :count)

    expect(ReadConfirmation.exists?(confirmation.id)).to be(true)
    expect(response).to redirect_to(root_path)
    follow_redirect!
    expect(response.body).to include("メンテナンス中のため既読確認の変更は停止しています")
  end

  it "marks the document as read when showing document detail" do
    sign_in_as(user)

    expect do
      get project_document_path(project, document.slug)
    end.to change(ReadConfirmation, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("既読確認済み")
    expect(response.body).to include("既読を解除")
  end
end
