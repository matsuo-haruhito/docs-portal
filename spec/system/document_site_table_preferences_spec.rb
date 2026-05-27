require "rails_helper"
require "fileutils"
require "securerandom"
require "timeout"

RSpec.describe "Document site table preferences", type: :system do
  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1600, 1400])
  end

  let(:site_build_path) { "docs-#{SecureRandom.hex(3)}/dispatch-api-spec/v1.0.0" }
  let(:user) { create(:user) }
  let(:project) { create(:project, code: "PJ#{SecureRandom.hex(4)}", name: "Project #{SecureRandom.hex(2)}") }
  let(:document) do
    create(
      :document,
      project:,
      title: "配車管理API仕様書",
      slug: "dispatch-api-spec"
    )
  end
  let(:version) do
    create(
      :document_version,
      document:,
      version_label: "v1.0.0",
      site_build_path:
    )
  end

  before do
    FileUtils.mkdir_p(version.site_root_absolute_path.join(site_build_path))
    File.write(
      version.site_root_absolute_path.join(site_build_path, "index.html"),
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head></head>
          <body>
            <article class="theme-doc-markdown">
              <table>
                <thead>
                  <tr>
                    <th>項目</th>
                    <th>値</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Alpha</td>
                    <td>100</td>
                  </tr>
                </tbody>
              </table>
              <table>
                <thead>
                  <tr>
                    <th>状態</th>
                    <th>詳細</th>
                  </tr>
                </thead>
                <tbody>
                  <tr>
                    <td>Beta</td>
                    <td>公開中</td>
                  </tr>
                </tbody>
              </table>
            </article>
          </body>
        </html>
      HTML
    )
  end

  after do
    FileUtils.rm_rf(version.site_root_absolute_path) if version.id
  end

  def sign_in_via_browser(user)
    visit new_session_path

    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "password123!"
    click_button "ログイン"

    expect(page).to have_current_path(root_path, ignore_query: true)
  end

  def wait_for_viewer_preference_panels
    expect(page).to have_css("iframe.site-viewer-frame", wait: 10)

    within_frame(find("iframe.site-viewer-frame")) do
      expect(page).to have_css(".portal-table-width-frame", count: 2, wait: 10)
      expect(page).to have_css(".portal-table-preference-panel", count: 2, visible: :all, wait: 10)
    end
  end

  def viewer_table_infos
    within_frame(find("iframe.site-viewer-frame")) do
      page.evaluate_script(<<~JS)
        Array.from(document.querySelectorAll(".portal-table-width-frame")).map((wrapper) => ({
          tableKey: wrapper.dataset.railsTablePreferencesTableKey,
          columnKeys: Array.from(wrapper.querySelectorAll("thead th")).map((cell) => cell.dataset.railsTablePreferencesColumnKey),
          rowState: Array.from(wrapper.querySelectorAll("tbody tr:first-child td")).map((cell) => ({
            text: cell.textContent.trim(),
            hidden: cell.hidden
          }))
        }))
      JS
    end
  end

  def save_table_visibility(panel_index:, table_key:, checked_states:)
    within_frame(find("iframe.site-viewer-frame")) do
      statements = checked_states.each_with_index.map do |checked, index|
        "checkboxes[#{index}].checked = #{checked ? 'true' : 'false'}"
      end.join("\n")

      page.execute_script(<<~JS)
        const panel = document.querySelectorAll(".portal-table-preference-panel")[#{panel_index}]
        panel.open = true

        const checkboxes = panel.querySelectorAll('input[type="checkbox"]')
        #{statements}

        Array.from(panel.querySelectorAll("button"))
          .find((button) => button.textContent.trim() === "保存")
          ?.click()
      JS
    end

    Timeout.timeout(10) do
      loop do
        preference = RailsTablePreferences::Preference.find_for(user:, table_key:)
        break if preference.present? && preference.settings.fetch("columns").map { |column| column["visible"] } == checked_states

        sleep 0.1
      end
    end
  end

  it "loads and saves per-table column preferences without colliding keys" do
    sign_in_via_browser(user)
    visit site_document_version_path(version, site_path: site_build_path)
    wait_for_viewer_preference_panels

    initial_infos = viewer_table_infos
    table_keys = initial_infos.map { _1.fetch("tableKey") }

    aggregate_failures do
      expect(table_keys.size).to eq(2)
      expect(table_keys.uniq.size).to eq(2)
      expect(initial_infos.map { _1.fetch("columnKeys") }).to all(eq(%w[column_1 column_2]))
    end

    save_table_visibility(panel_index: 0, table_key: table_keys.first, checked_states: [true, false])
    save_table_visibility(panel_index: 1, table_key: table_keys.second, checked_states: [false, true])

    first_saved = RailsTablePreferences::Preference.find_for(user:, table_key: table_keys.first)
    second_saved = RailsTablePreferences::Preference.find_for(user:, table_key: table_keys.second)

    aggregate_failures do
      expect(first_saved).to be_present
      expect(second_saved).to be_present
      expect(first_saved.settings.fetch("columns")).to include(
        a_hash_including("key" => "column_1", "visible" => true),
        a_hash_including("key" => "column_2", "visible" => false)
      )
      expect(second_saved.settings.fetch("columns")).to include(
        a_hash_including("key" => "column_1", "visible" => false),
        a_hash_including("key" => "column_2", "visible" => true)
      )
    end

    visit site_document_version_path(version, site_path: site_build_path)
    wait_for_viewer_preference_panels

    loaded_infos = viewer_table_infos

    aggregate_failures do
      expect(loaded_infos[0].fetch("rowState")).to contain_exactly(
        a_hash_including("text" => "Alpha", "hidden" => false),
        a_hash_including("text" => "100", "hidden" => true)
      )
      expect(loaded_infos[1].fetch("rowState")).to contain_exactly(
        a_hash_including("text" => "Beta", "hidden" => true),
        a_hash_including("text" => "公開中", "hidden" => false)
      )
    end
  end
end
