require "rails_helper"

RSpec.describe MicrosoftGraphConnection, type: :model do
  describe "enabled connection validation" do
    it "does not allow more than one enabled connection in the same project" do
      project = create(:project)
      create(:microsoft_graph_connection, project:, enabled: true)

      duplicate = build(:microsoft_graph_connection, project:, enabled: true)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:enabled]).to include("は同一案件で1件だけ有効にできます。切り替える場合は現在の有効接続を先に無効化してください。")
    end

    it "allows a disabled connection when another enabled connection already exists" do
      project = create(:project)
      create(:microsoft_graph_connection, project:, enabled: true)

      standby = build(:microsoft_graph_connection, project:, enabled: false)

      expect(standby).to be_valid
    end
  end

  describe "#preview_selected?" do
    it "returns true only for the connection currently used for preview in that project" do
      project = create(:project)
      selected = create(:microsoft_graph_connection, project:, enabled: true)
      standby = build(:microsoft_graph_connection, project:, enabled: true)
      standby.save!(validate: false)

      expect(selected.preview_selected?).to be(true)
      expect(standby.preview_selected?).to be(false)
    end
  end
end