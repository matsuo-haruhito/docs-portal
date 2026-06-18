require "rails_helper"
require "selenium-webdriver"
require "tmpdir"

RSpec.describe "document delivery log action groups browser smoke", type: :request do
  VIEWPORTS = {
    "desktop" => [1280, 900],
    "narrow" => [390, 844]
  }.freeze

  let(:company) { create(:company) }
  let(:external_user) { create(:user, :external, company:) }
  let(:project) { create(:project, code: "DLV1", name: "Delivery Project") }
  let(:document) { create(:document, project:, title: "Shared Manual", slug: "shared-manual", visibility_policy: :restricted_external) }
  let(:version) { create(:document_version, document:, version_label: "v1.0.0", status: :published) }

  before do
    document.update!(latest_version: version)
    create(:project_membership, project:, user: external_user)
    create(:document_permission, document:, company:, access_level: :view)
    sign_in_as(external_user)
  end

  it "keeps draft and sent action groups visible without viewport overflow" do
    variants = {
      "draft" => rendered_delivery_log_html(status: :draft, subject: "Please review", return_to: document_delivery_logs_path(status: :draft)),
      "sent" => rendered_delivery_log_html(status: :sent, subject: "Sent notice", return_to: document_delivery_logs_path(status: :sent))
    }

    with_chrome_driver do |driver|
      VIEWPORTS.each do |viewport_name, (width, height)|
        driver.manage.window.resize_to(width, height)

        variants.each do |variant, html|
          driver.navigate.to("file://#{static_page_path(variant, html)}")

          failures = driver.execute_script(browser_checks_script(variant))
          expect(failures).to be_empty, "#{variant} / #{viewport_name}: #{failures.join(', ')}"
        end
      end
    end
  end

  def rendered_delivery_log_html(status:, subject:, return_to:)
    log = create(
      :document_delivery_log,
      project:,
      document:,
      sender: external_user,
      status:,
      delivery_type: :portal_link,
      to_addresses: "client@example.com",
      subject:,
      body: "Portal link"
    )

    get document_delivery_log_path(log), params: { return_to: return_to }
    expect(response).to have_http_status(:ok)

    html_with_smoke_styles(response.body)
  end

  def html_with_smoke_styles(html)
    html.sub(
      "</head>",
      <<~HTML
        <style>
          * { box-sizing: border-box; }
          body { margin: 0; font-family: system-ui, sans-serif; color: #0f172a; background: #f8fafc; }
          main, body > div, body > .container { max-width: 920px; margin: 0 auto; padding: 20px; }
          table { width: 100%; border-collapse: collapse; }
          th, td { padding: 6px 8px; border-bottom: 1px solid #e2e8f0; text-align: left; vertical-align: top; }
          pre { max-width: 100%; white-space: pre-wrap; overflow-wrap: anywhere; }
          .muted { color: #64748b; }
          .button, button { display: inline-flex; align-items: center; min-height: 36px; max-width: 100%; padding: 8px 12px; border-radius: 8px; border: 1px solid #cbd5e1; text-decoration: none; white-space: normal; }
          .actions { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
          .delivery-log-actions { display: grid; gap: 14px; margin-top: 20px; }
          .delivery-log-actions__group { padding-top: 10px; border-top: 1px solid #e2e8f0; }
        </style>
      </head>
      HTML
    )
  end

  def with_chrome_driver
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--window-size=1280,900")

    driver = Selenium::WebDriver.for(:chrome, options:)
    yield driver
  ensure
    driver&.quit
  end

  def static_page_path(variant, html)
    file = Tempfile.new(["document-delivery-log-#{variant}", ".html"])
    file.write(html)
    file.close
    file.path
  end

  def browser_checks_script(variant)
    <<~JS
      const variant = #{variant.to_json};
      const failures = [];
      const viewport = window.innerWidth;
      const documentWidth = document.documentElement.scrollWidth;
      if (documentWidth > viewport + 1) failures.push(`horizontal overflow ${documentWidth} > ${viewport}`);

      const inputValues = Array.from(document.querySelectorAll("input[type='submit'], input[type='button']"))
        .map((input) => input.value)
        .join(" ");
      const text = document.body.innerText + " " + inputValues;
      const requiredText = ["操作", "メール作成", "対象へ戻る", "メーラーを開く", "対象の文書へ戻る", "送付履歴一覧へ戻る"];
      if (variant === "draft") requiredText.push("手動状態更新", "送付済みにする", "送付失敗として記録", "失敗理由");
      if (variant === "sent") requiredText.push("この履歴は下書きではないため、状態を手動で変更する操作は表示されません。");
      requiredText.forEach((value) => { if (!text.includes(value)) failures.push(`missing text ${value}`); });
      if (variant === "sent" && text.includes("手動状態更新")) failures.push("sent state shows manual update group");

      const groups = Array.from(document.querySelectorAll(".delivery-log-actions__group"));
      const expectedGroupCount = variant === "draft" ? 3 : 2;
      if (groups.length !== expectedGroupCount) failures.push(`group count ${groups.length} !== ${expectedGroupCount}`);

      const actionSection = document.querySelector(".delivery-log-actions");
      if (!actionSection) failures.push("missing action section");
      if (actionSection) {
        const sectionRect = actionSection.getBoundingClientRect();
        if (sectionRect.width <= 0 || sectionRect.height <= 0) failures.push("action section not visible");
        if (sectionRect.left < -1 || sectionRect.right > viewport + 1) failures.push("action section overflows viewport");
      }

      groups.forEach((group, index) => {
        const rect = group.getBoundingClientRect();
        if (rect.width <= 0 || rect.height <= 0) failures.push(`group ${index} not visible`);
        if (rect.left < -1 || rect.right > viewport + 1) failures.push(`group ${index} overflows viewport`);
        const actions = Array.from(group.querySelectorAll("a, button, input[type='submit']"));
        if (actions.length === 0) failures.push(`group ${index} has no visible action`);
        actions.forEach((action) => {
          const actionRect = action.getBoundingClientRect();
          if (actionRect.width <= 0 || actionRect.height <= 0) failures.push(`hidden action ${action.textContent || action.value}`);
          if (actionRect.left < -1 || actionRect.right > viewport + 1) failures.push(`action overflow ${action.textContent || action.value}`);
        });
      });

      for (let index = 1; index < groups.length; index += 1) {
        const previous = groups[index - 1].getBoundingClientRect();
        const current = groups[index].getBoundingClientRect();
        if (current.top < previous.bottom - 1) failures.push(`vertical overlap before group ${index}`);
      }

      return failures;
    JS
  end
end
