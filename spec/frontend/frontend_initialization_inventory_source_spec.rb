require "rails_helper"

RSpec.describe "frontend initialization inventory source" do
  def read_source(path)
    Rails.root.join(path).read
  end

  let(:entrypoint_source) { read_source("app/frontend/entrypoints/application.js") }
  let(:inventory_source) { read_source("doc/frontend_initialization_inventory.md") }
  let(:interaction_policy_source) { read_source("doc/frontend_interaction_policy.md") }
  let(:roadmap_source) { read_source("ROADMAP.md") }

  let(:direct_entrypoint_setup_patterns) do
    {
      "querySelectorAll" => "Move DOM scanning into a Stimulus controller or dedicated module instead of app/frontend/entrypoints/application.js.",
      "addEventListener" => "Keep browser event listeners inside Stimulus lifecycle methods or a dedicated module, not the Vite entrypoint.",
      "new TomSelect" => "Use rails_fields_kit helpers and the gem-provided Stimulus controller instead of app-side Tom Select initialization."
    }
  end

  it "keeps the Vite entrypoint limited to imports and Stimulus controller registration" do
    aggregate_failures do
      expect(entrypoint_source).to include('import { Application } from "@hotwired/stimulus"')
      expect(entrypoint_source).to include("const application = Application.start()")
      expect(entrypoint_source).to include('application.register("rails-table-preferences", RailsTablePreferencesController)')
      expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", TomSelectController)')

      direct_entrypoint_setup_patterns.each do |pattern, failure_message|
        expect(entrypoint_source).not_to include(pattern), failure_message
      end
    end
  end

  it "keeps the inventory and policy aligned with the entrypoint guard" do
    aggregate_failures do
      expect(inventory_source).to include("`app/frontend/entrypoints/application.js`")
      expect(inventory_source).to include("Stimulus application を起動し、gem controller と app controller を明示登録する")
      expect(inventory_source).to include("controller 登録以外の直接 `querySelectorAll`、直接 event listener、直接 `new TomSelect(...)` は置かれていません")
      expect(inventory_source).to include("`application.js` の直接 DOM setup は追加しない")
      expect(inventory_source).to include("app 側 `new TomSelect(...)` は追加しない")

      expect(interaction_policy_source).to include("`application.js` に直接 `querySelectorAll` とイベント登録を増やさない")
      expect(interaction_policy_source).to include("アプリ側で `new TomSelect(...)` を直接呼ぶ手書き初期化を増やすこと")
      expect(roadmap_source).to include("`application.js` に `querySelectorAll` とイベント登録を直接増やさない")
    end
  end
end
