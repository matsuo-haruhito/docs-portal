# frozen_string_literal: true

require "rails_helper"

RSpec.describe "admin/external_folder_sync_sources/index source" do
  let(:source) { Rails.root.join("app/views/admin/external_folder_sync_sources/index.html.slim").read }

  it "keeps provider operation boundary copy explicit" do
    expect(source).to include("同期実行対象")
    expect(source).to include("dry-run / apply 可能")
    expect(source).to include("メタデータ確認のみ")
    expect(source).to include("dry-run / apply 未対応")
    expect(source).to include("SharePoint / OneDrive はメタデータ確認のみとして drive_id / folder_path など保存情報の確認に留めます")
  end

  it "keeps table preferences column keys stable" do
    %w[project name provider external_folder_location status last_synced_at latest_safety warning_count latest_error actions].each do |column_key|
      expect(source).to include(%(data-rails-table-preferences-column-key="#{column_key}"))
    end
  end

  it "does not present Microsoft Graph sources as sync executable" do
    expect(source).not_to include("SharePoint / OneDrive は dry-run / apply")
    expect(source).not_to include("Microsoft Graph は同期実行対象")
  end
end
