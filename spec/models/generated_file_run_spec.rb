require "rails_helper"

RSpec.describe GeneratedFileRun, type: :model do
  describe "validations" do
    it "requires a job id" do
      run = described_class.new(job_id: nil)

      expect(run).not_to be_valid
      expect(run.errors[:job_id]).to be_present
    end
  end

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

    it "stores an empty generated path list when generated paths are nil" do
      run = create(:generated_file_run, status: :running, generated_paths: ["old.md"], finished_at: nil)

      run.finish!(status: :completed, generated_paths: nil)

      expect(run).to be_completed
      expect(run.generated_paths).to eq([])
      expect(run.finished_at).to be_present
    end
  end
end
