require "rails_helper"
require "fileutils"
require "securerandom"
require "timeout"

RSpec.describe "Document site table preferences", type: :system do
  before do
    driven_by_headless_chrome(screen_size: [1600, 1400])
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

  def install_preference_request_probe
    page.execute_script(<<~JS)
      window.__docsPortalPreferenceRequests = []

      if (window.__docsPortalPreferenceFetchWrapped) {
        return
      }

      const originalFetch = window.fetch.bind(window)
      window.__docsPortalPreferenceFetchWrapped = true
      window.fetch = async (input, init = {}) => {
        const url = typeof input === "string" ? input : input.url
        const method = (init.method || "GET").toUpperCase()

        try {
          const response = await originalFetch(input, init)
          window.__docsPortalPreferenceRequests.push({ url, method, status: response.status })
          return response
        } catch (error) {
          window.__docsPortalPreferenceRequests.push({ url, method, error: String(error) })
          throw error
        }
      }
    JS
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

  def wait_for_preference_request(table_key, method:, statuses:)
    Timeout.timeout(10) do
      loop do
        request = page.evaluate_script(<<~JS)
          (() => {
            const encodedTableKey = encodeURIComponent(#{table_key.to_json})
            const requests = window.__docsPortalPreferenceRequests || []
            return requests.find((entry) => {
              if (typeof entry.url !== "string") return false
              if (entry.method !== #{method.to_json}) return false
              if (!entry.url.includes(`/rails_table_preferences/preferences/${encodedTableKey}`)) return false
              return #{statuses}.includes(entry.status)
            }) || null
          })()
        JS

        return request if request

        sleep 0.1
      end
    end
  rescue Timeout::Error
    requests = page.evaluate_script("window.__docsPortalPreferenceRequests || []")
    raise "Timed out waiting for #{method} preference request for #{table_key}: #{requests.inspect}"
  end

  def wait_for_preference_save_request(table_key)
    wait_for_preference_request(table_key, method: "PATCH", statuses: [200]) ||
      wait_for_preference_request(table_key, method: "POST", statuses: [201])
  rescue RuntimeError
    wait_for_preference_request(table_key, method: "POST", statuses: [201])
  end

  def wait_for_preference_load_request(table_key)
    wait_for_preference_request(table_key, method: "GET", statuses: [200])
  end

  def wait_for_reloaded_hidden_columns
    Timeout.timeout(10) do
      loop do
        loaded_infos = viewer_table_infos
        first_hidden = loaded_infos.dig(0, "rowState", 1, "hidden")
        second_hidden = loaded_infos.dig(1, "rowState", 0, "hidden")
        return if first_hidden == true && second_hidden == true
        sleep 0.1
      end
    end
  rescue Timeout::Error
    raise "Timed out waiting for reloaded hidden columns: #{viewer_table_infos.inspect}"
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

    wait_for_preference_save_request(table_key)
  end

  it "loads and saves per-table column preferences without colliding keys" do
    sign_in_via_browser(user)
    visit site_document_version_path(version, site_path: site_build_path)
    wait_for_viewer_preference_panels
    install_preference_request_probe

    initial_infos = viewer_table_infos
    table_keys = initial_infos.map { _1.fetch("tableKey") }

    aggregate_failures do
      expect(table_keys.size).to eq(2)
      expect(table_keys.uniq.size).to eq(2)
      expect(initial_infos.map { _1.fetch("columnKeys") }).to all(eq(%w[column_1 column_2]))
    end

    first_save_request = save_table_visibility(panel_index: 0, table_key: table_keys.first, checked_states: [true, false])
    second_save_request = save_table_visibility(panel_index: 1, table_key: table_keys.second, checked_states: [false, true])

    aggregate_failures do
      expect([200, 201]).to include(first_save_request.fetch("status"))
      expect([200, 201]).to include(second_save_request.fetch("status"))
    end

    visit site_document_version_path(version, site_path: site_build_path)
    install_preference_request_probe
    wait_for_viewer_preference_panels
    wait_for_preference_load_request(table_keys.first)
    wait_for_preference_load_request(table_keys.second)
    wait_for_reloaded_hidden_columns

    loaded_infos = viewer_table_infos
    expected_row_states = [
      [
        { "text" => "Alpha", "hidden" => false },
        { "text" => "100", "hidden" => true }
      ],
      [
        { "text" => "Beta", "hidden" => true },
        { "text" => "公開中", "hidden" => false }
      ]
    ]

    aggregate_failures do
      expect(loaded_infos[0].fetch("rowState")).to eq(expected_row_states[0])
      expect(loaded_infos[1].fetch("rowState")).to eq(expected_row_states[1])
    end
  end
end
