require "rails_helper"

RSpec.describe RecentDocumentsQuery do
  let(:company) { create(:company) }
  let(:project) { create(:project) }
  let(:user) { create(:user, :external, company:) }

  def create_viewable_document(title:, slug:)
    document = create(:document, project:, title:, slug:, visibility_policy: :restricted_external)
    create(:project_membership, project:, user:)
    create(:document_permission, document:, company:, access_level: :view)
    document
  end

  def log_view(document, accessed_at: Time.current)
    create(
      :access_log,
      user:,
      company: user.company,
      project: document.project,
      document:,
      action_type: :view,
      target_type: "document",
      accessed_at:
    )
  end

  it "returns recently viewed documents in latest access order" do
    older = create_viewable_document(title: "Older", slug: "older")
    newer = create_viewable_document(title: "Newer", slug: "newer")
    log_view(older, accessed_at: 2.days.ago)
    log_view(newer, accessed_at: 1.day.ago)

    documents = described_class.new(user:).call

    expect(documents).to eq([newer, older])
  end

  it "keeps only the latest view per document" do
    first = create_viewable_document(title: "First", slug: "first")
    second = create_viewable_document(title: "Second", slug: "second")
    log_view(first, accessed_at: 3.days.ago)
    log_view(second, accessed_at: 2.days.ago)
    log_view(first, accessed_at: 1.day.ago)

    documents = described_class.new(user:).call

    expect(documents).to eq([first, second])
  end

  it "excludes documents that are no longer viewable" do
    visible = create_viewable_document(title: "Visible", slug: "visible")
    hidden = create_viewable_document(title: "Hidden", slug: "hidden")
    hidden.update!(visibility_policy: :internal_only)
    log_view(visible, accessed_at: 2.days.ago)
    log_view(hidden, accessed_at: 1.day.ago)

    documents = described_class.new(user:).call

    expect(documents).to eq([visible])
  end

  it "respects the requested limit" do
    first = create_viewable_document(title: "First", slug: "first")
    second = create_viewable_document(title: "Second", slug: "second")
    log_view(first, accessed_at: 2.days.ago)
    log_view(second, accessed_at: 1.day.ago)

    documents = described_class.new(user:, limit: 1).call

    expect(documents).to eq([second])
  end

  it "returns an empty list for inactive users" do
    user.update!(active: false)
    document = create(:document, project:, title: "Document", slug: "document")
    log_view(document)

    documents = described_class.new(user:).call

    expect(documents).to be_empty
  end
end
