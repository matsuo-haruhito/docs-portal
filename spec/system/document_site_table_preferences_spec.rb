require "rails_helper"
require "fileutils"
require "securerandom"

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

  def post_default_preference(table_key, settings)
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]

      fetch(`/rails_table_preferences/preferences/${encodeURIComponent(#{table_key.to_json})}`, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        body: JSON.stringify({ name: "default", settings: #{settings.to_json} })
      })
        .then(async (response) => done({ status: response.status, body: await response.json() }))
        .catch((error) => done({ error: String(error) }))
    JS
  end

  def fetch_default_preference(table_key)
    page.evaluate_async_script(<<~JS)
      const done = arguments[0]

      fetch(`/rails_table_preferences/preferences/${encodeURIComponent(#{table_key.to_json})}/default`, {
        headers: { "Accept": "application/json" }
      })
        .then(async (response) => done({ status: response.status, body: await response.json() }))
        .catch((error) => done({ error: String(error) }))
    JS
  end

  def reload_viewer_frame
    frame = find("iframe.site-viewer-frame")
    page.execute_script("arguments[0].src = arguments[0].src", frame)
    wait_for_viewer_preference_panels
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

    first_preference = post_default_preference(
      table_keys.first,
      {
        columns: [
          { key: "column_1", visible: true, order: 10 },
          { key: "column_2", visible: false, order: 20 }
        ],
        filters: {},
        sorts: []
      }
    )
    second_preference = post_default_preference(
      table_keys.second,
      {
        columns: [
          { key: "column_1", visible: false, order: 10 },
          { key: "column_2", visible: true, order: 20 }
        ],
        filters: {},
        sorts: []
      }
    )

    expect(first_preference).to include("status" => 201)
    expect(second_preference).to include("status" => 201)

    reload_viewer_frame

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

    within_frame(find("iframe.site-viewer-frame")) do
      page.execute_script(<<~JS)
        const panel = document.querySelectorAll(".portal-table-preference-panel")[1]
        panel.open = true

        const checkboxes = panel.querySelectorAll('input[type="checkbox"]')
        checkboxes[0].checked = true
        checkboxes[1].checked = false

        Array.from(panel.querySelectorAll("button"))
          .find((button) => button.textContent.trim() === "保存")
          ?.click()
      JS

      expect(page).to have_text("保存しました", wait: 10)
    end

    saved_preference = fetch_default_preference(table_keys.second)
    saved_columns = saved_preference.dig("body", "settings", "columns")

    expect(saved_preference).to include("status" => 200)
    expect(saved_columns).to include(
      a_hash_including("key" => "column_1", "visible" => true),
      a_hash_including("key" => "column_2", "visible" => false)
    )
  end
end
