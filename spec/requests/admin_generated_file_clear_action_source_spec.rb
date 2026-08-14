require "rails_helper"

RSpec.describe "Generated file clear action source", type: :request do
  def source_for(path)
    Rails.root.join(path).read
  end

  it "shows the generated file events clear link only when filters are active" do
    source = source_for("app/views/admin/generated_file_events/index.html.slim")

    aggregate_failures do
      expect(source).to include("- has_active_filters = @filters.compact_blank.any?")
      expect(source).to match(%r{= form\.submit "絞り込み", class: "rounded bg-blue-600 px-3 py-2 text-sm text-white"\s+- if has_active_filters\s+= link_to "絞り込みを解除", admin_generated_file_events_path, class: "rounded border px-3 py-2 text-sm"})
      expect(source).not_to match(%r{= form\.submit "絞り込み", class: "rounded bg-blue-600 px-3 py-2 text-sm text-white"\s+= link_to "絞り込みを解除", admin_generated_file_events_path, class: "rounded border px-3 py-2 text-sm"})
    end
  end

  it "shows the generated file runs clear link only when filters are active" do
    source = source_for("app/views/admin/generated_file_runs/index.html.slim")

    aggregate_failures do
      expect(source).to include("- has_active_filters = @filters.compact_blank.any?")
      expect(source).to match(%r{= form\.submit "絞り込み", class: "rounded bg-blue-600 px-3 py-2 text-sm text-white"\s+- if has_active_filters\s+= link_to "絞り込みを解除", admin_generated_file_runs_path, class: "rounded border px-3 py-2 text-sm"})
      expect(source).not_to match(%r{= form\.submit "絞り込み", class: "rounded bg-blue-600 px-3 py-2 text-sm text-white"\s+= link_to "絞り込みを解除", admin_generated_file_runs_path, class: "rounded border px-3 py-2 text-sm"})
    end
  end
end
