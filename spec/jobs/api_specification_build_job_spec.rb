require "rails_helper"

RSpec.describe ApiSpecificationBuildJob, type: :job do
  it "clears the build request marker when the build fails" do
    page = instance_double(Admin::ApiSpecificationPage)
    allow(page).to receive(:build!).and_raise("build failed")
    allow(page).to receive(:clear_build_request!)
    allow(Admin::ApiSpecificationPage).to receive(:new).and_return(page)

    expect { described_class.perform_now }.to raise_error("build failed")

    expect(page).to have_received(:clear_build_request!)
  end
end
