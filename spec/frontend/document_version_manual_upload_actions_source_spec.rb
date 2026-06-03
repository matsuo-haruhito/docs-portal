require "rails_helper"

RSpec.describe "document version manual upload action source" do
  let(:view_source) { Rails.root.join("app/views/document_versions/_rollback_actions.html.slim").read }
  let(:review_service_source) { Rails.root.join("app/services/manual_document_upload_review.rb").read }
  let(:rollback_service_source) { Rails.root.join("app/services/document_version_rollback.rb").read }

  it "keeps manual upload actions limited to internal users and manual upload versions" do
    expect(view_source).to include("manual_upload_version = @version.source_commit_hash == ManualDocumentUploadReview::MANUAL_UPLOAD_SOURCE")
    expect(view_source).to include("current_user.internal? && manual_upload_version")
    expect(view_source).to include("@version.draft?")
    expect(view_source).to include("@document.latest_version_id == @version.id")
  end

  it "explains the draft candidate approve and reject outcomes without changing routes" do
    expect(view_source).to include("候補版を最新版として反映するか破棄するかを選びます")
    expect(view_source).to include("OK はこの候補版を published にし、文書の latest version として反映します")
    expect(view_source).to include("NG はこの候補版を破棄し、候補だけを archived にします")
    expect(view_source).to include("公開済み版がない文書では文書も archived になる場合があります")
    expect(view_source).to include("document_version_upload_review_path(@version)")
    expect(view_source).to include("decision: \"approve\"")
    expect(view_source).to include("decision: \"reject\"")
    expect(review_service_source).to include("version.document.update!(latest_version: version)")
    expect(review_service_source).to include("document.archive!(actor: actor) if document.latest_version.blank? && document.document_versions.published.none?")
  end

  it "explains rollback impact without changing the rollback route" do
    expect(view_source).to include("反映済みの手動アップロード最新版に誤りがある場合だけ、この版を取り消します")
    expect(view_source).to include("直前の published version があれば文書の latest version をそこへ戻します")
    expect(view_source).to include("戻せる published version がない場合は、文書も archived になります")
    expect(view_source).to include("document_version_rollback_path(@version)")
    expect(rollback_service_source).to include("document.update!(latest_version: previous_version)")
    expect(rollback_service_source).to include("document.update!(latest_version: nil)")
    expect(rollback_service_source).to include("document.archive!(actor: actor)")
  end

  it "separates navigation copy from state-changing actions" do
    expect(view_source).to include("確認を続ける場合は、この操作を実行せず文書一覧へ戻れます")
    expect(view_source).to include("操作せず確認を終える場合は、文書一覧へ戻れます")
    expect(view_source.scan("project_documents_path(@project, upload_source_path: @version.source_directory)").size).to eq(2)
  end
end
