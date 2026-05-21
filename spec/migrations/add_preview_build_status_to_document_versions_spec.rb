require "rails_helper"

RSpec.describe "preview build status schema" do
  it "has preview build status columns on document_versions" do
    columns = ActiveRecord::Base.connection.columns(:document_versions).index_by(&:name)

    expect(columns).to include(
      "preview_build_status",
      "preview_build_error_message",
      "preview_build_attempted_at",
      "preview_build_completed_at"
    )
    expect(columns.fetch("preview_build_status").default.to_i).to eq(0)
    expect(columns.fetch("preview_build_status").null).to eq(false)
  end

  it "has indexes for preview build status lookup" do
    indexes = ActiveRecord::Base.connection.indexes(:document_versions).map(&:columns)

    expect(indexes).to include(["preview_build_status"])
    expect(indexes).to include(["preview_build_attempted_at"])
  end
end
