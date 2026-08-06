# frozen_string_literal: true

require "rails_helper"

RSpec.describe "bin/validate_external_samples format support" do
  let(:script_path) { Rails.root.join("bin/validate_external_samples").to_s }

  it "rejects unsupported format with exit 2" do
    output = `ruby #{script_path} --format=csv 2>&1`
    expect($?.exitstatus).to eq(2)
    expect(output).to include("Unsupported format")
  end

  it "accepts --format=markdown without syntax errors" do
    # Just verify the format is accepted (not exit 2) by using a non-existent root
    # to trigger a warning path that still exercises format acceptance
    output = `ruby #{script_path} --format=markdown --root=tmp/nonexistent_sample_root 2>&1`
    expect($?.exitstatus).not_to eq(2)
  end

  it "accepts --format=text without syntax errors" do
    output = `ruby #{script_path} --format=text --root=tmp/nonexistent_sample_root 2>&1`
    expect($?.exitstatus).not_to eq(2)
  end

  it "accepts --format=json without syntax errors" do
    output = `ruby #{script_path} --format=json --root=tmp/nonexistent_sample_root 2>&1`
    expect($?.exitstatus).not_to eq(2)
  end

  it "markdown format outputs a markdown table with summary" do
    # Create minimal sample root to get valid output
    root = Rails.root.join("tmp/spec/validate_format_test")
    FileUtils.rm_rf(root)
    source_dir = root.join("sample-set/site")
    FileUtils.mkdir_p(source_dir)
    File.write(source_dir.join("index.md"), "# Test\n")

    output = `ruby #{script_path} --format=markdown --root=#{root} 2>&1`
    expect($?.exitstatus).to eq(0)
    expect(output).to include("## External Sample Validation")
    expect(output).to include("| 結果 |")
    expect(output).to include("| 案件数 |")
    expect(output).to include("dry-run only")
    expect(output).not_to include(root.to_s) # raw absolute path 抑制

    FileUtils.rm_rf(root)
  end
end
