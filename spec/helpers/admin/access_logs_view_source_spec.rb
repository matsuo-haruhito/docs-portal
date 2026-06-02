require "rails_helper"

RSpec.describe "admin/access_logs/index source" do
  let(:source) { Rails.root.join("app/views/admin/access_logs/index.html.slim").read }

  it "keeps parsed AI context target details primary and raw target_name secondary" do
    expect(source).to include("ai_context_target[:segments].each")
    expect(source).to include("span.badge title=ai_context_target[:raw]")
    expect(source).to include("details")
    expect(source).to include("summary.muted 監査用 raw target_name")
    expect(source).to include("code.muted = ai_context_target[:raw]")
  end

  it "keeps the target table preference column key stable" do
    expect(source).to include('th data-rails-table-preferences-column-key="target" 対象')
    expect(source).to include('td data-rails-table-preferences-column-key="target"')
  end
end
