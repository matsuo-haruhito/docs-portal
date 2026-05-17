require "rails_helper"

RSpec.describe DocumentFilePreviewResultHelpers do
  let(:result_class) do
    Data.define(:truncated, :error) do
      include DocumentFilePreviewResultHelpers
    end
  end

  it "reports truncation when a result has a true truncated value" do
    expect(result_class.new(truncated: true, error: nil)).to be_truncated
    expect(result_class.new(truncated: false, error: nil)).not_to be_truncated
  end

  it "reports errors when a result has an error message" do
    expect(result_class.new(truncated: false, error: "invalid")).to be_error
    expect(result_class.new(truncated: false, error: nil)).not_to be_error
  end

  it "treats results without truncated as not truncated" do
    klass = Data.define(:error) do
      include DocumentFilePreviewResultHelpers
    end

    expect(klass.new(error: nil)).not_to be_truncated
  end
end
