require "rails_helper"

RSpec.describe GeneratedFileRun, type: :model do
  describe "#finish!" do
    it "stores the final status, generated paths, error message, and finish time" do
      run = create(:generated_file_run, status: :running, generated_paths: [], error_message: nil, finished_at: nil)

      run.finish!(
        status: :failed,
        generated_paths: ["generated.md"],
        error_message: "boom"
      )

      expect(run).to be_failed
      expect(run.generated_paths).to eq(["generated.md"])
      expect(run.error_message).to eq("boom")
      expect(run.finished_at).to be_present
    end
  end
end
