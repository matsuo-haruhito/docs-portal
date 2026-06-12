require "rails_helper"

RSpec.describe "Generated file clear action source", type: :request do
  def source_for(path)
    Rails.root.join(path).read
  end

  it "shows the generated file events clear link only when filters are active" do
    source = source_for("app/views/admin/generated_file_events/index.html.erb")

    expect(source).to include(<<~ERB)
      <% if has_active_filters %>
        <%= link_to "クリア", admin_generated_file_events_path, class: "rounded border px-3 py-2 text-sm" %>
      <% end %>
    ERB
    expect(source).not_to include(<<~ERB)
      <%= form.submit "絞り込み", class: "rounded bg-blue-600 px-3 py-2 text-sm text-white" %>
      <%= link_to "クリア", admin_generated_file_events_path, class: "rounded border px-3 py-2 text-sm" %>
    ERB
  end

  it "shows the generated file runs clear link only when filters are active" do
    source = source_for("app/views/admin/generated_file_runs/index.html.erb")

    expect(source).to include(<<~ERB)
      <% if has_active_filters %>
        <%= link_to "クリア", admin_generated_file_runs_path, class: "rounded border px-3 py-2 text-sm" %>
      <% end %>
    ERB
    expect(source).not_to include(<<~ERB)
      <%= form.submit "絞り込み", class: "rounded bg-blue-600 px-3 py-2 text-sm text-white" %>
      <%= link_to "クリア", admin_generated_file_runs_path, class: "rounded border px-3 py-2 text-sm" %>
    ERB
  end
end
