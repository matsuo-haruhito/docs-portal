require "rails_helper"
require "selenium-webdriver"
require "tmpdir"

RSpec.describe "document comment workspace browser smoke" do
  VIEWPORTS = {
    "desktop" => [1280, 900],
    "narrow" => [390, 844]
  }.freeze

  VARIANTS = %w[floating inline].freeze

  let(:workspace_stylesheet) { Rails.root.join("app/assets/stylesheets/document_comment_workspace.css").read }

  it "keeps the summary, actions, search, and tabs readable in floating and inline layouts" do
    with_chrome_driver do |driver|
      VIEWPORTS.each do |viewport_name, (width, height)|
        driver.manage.window.resize_to(width, height)

        VARIANTS.each do |variant|
          driver.navigate.to("file://#{static_workspace_path(variant)}")

          failures = driver.execute_script(browser_checks_script(variant, viewport_name))
          expect(failures).to be_empty, "#{variant} / #{viewport_name}: #{failures.join(', ')}"
        end
      end
    end
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

  def static_workspace_path(variant)
    file = Tempfile.new(["document-comment-workspace-#{variant}", ".html"])
    file.write(static_workspace_html(variant))
    file.close
    file.path
  end

  def static_workspace_html(variant)
    <<~HTML
      <!doctype html>
      <html lang="ja">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body{margin:0;font-family:system-ui,sans-serif;background:#f8fafc;color:#0f172a}.page{max-width:920px;margin:0 auto;padding:24px}.card{box-sizing:border-box;padding:12px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;margin:12px 0}.muted{color:#64748b}.button{display:inline-flex;align-items:center;padding:8px 12px;border-radius:8px;background:#ff5000;color:#fff;text-decoration:none;border:0}.button.secondary{background:#f8fafc;color:#334155;border:1px solid #cbd5e1}.actions,.form-actions{display:flex;flex-wrap:wrap;gap:8px}.form-grid{display:grid;gap:10px}.form-field--full{grid-column:1/-1}input,textarea,select{box-sizing:border-box;max-width:100%;width:100%}
            #{workspace_stylesheet}
          </style>
        </head>
        <body>
          <main class="page">
            <h1>文書詳細</h1>
            <p class="muted">代表的な本文領域です。floating と inline の両方でコメント workspace を確認します。</p>
            #{workspace_markup(variant)}
          </main>
        </body>
      </html>
    HTML
  end

  def workspace_markup(variant)
    <<~HTML
      <details class="document-comment-workspace document-comment-workspace--#{variant}" open>
        <summary class="document-comment-workspace__fab" title="文書コメント" aria-label="文書コメントを開く">
          <span class="document-comment-workspace__fab-icon" aria-hidden="true">!</span>
          <span class="document-comment-workspace__fab-label">文書コメント</span>
        </summary>
        <div class="document-comment-workspace__panel" role="complementary" aria-label="文書コメント">
          <div class="document-comment-workspace__header">
            <div>
              <p class="document-comment-workspace__eyebrow">文書を見ながら書く</p>
              <h2>文書コメント</h2>
              <p class="muted">Q&amp;A と内部向けの確認事項をここにまとめます。</p>
            </div>
            <span class="document-comment-workspace__status">3件のQ&amp;A / 2件の確認事項<br>未解決: Q&amp;A 1件 / 確認事項 1件</span>
          </div>

          <div class="document-comment-workspace__summary" aria-label="文書コメントの件数">
            <div class="document-comment-workspace__summary-item">
              <span class="document-comment-workspace__summary-label">Q&amp;A</span>
              <strong class="document-comment-workspace__summary-value">3</strong>
              <span class="document-comment-workspace__summary-note">未解決 1件</span>
            </div>
            <div class="document-comment-workspace__summary-item document-comment-workspace__summary-item--internal">
              <span class="document-comment-workspace__summary-label">確認事項</span>
              <strong class="document-comment-workspace__summary-value">2</strong>
              <span class="document-comment-workspace__summary-note">未解決 1件</span>
            </div>
            <p class="document-comment-workspace__summary-help muted">未解決タブには、未解決のQ&amp;Aと内部向け確認事項をまとめて表示します。通知・期限・SLAを示すものではありません。</p>
          </div>

          <div class="document-comment-workspace__mode card">
            <h3>追加する内容</h3>
            <div class="comment-mode-switch">
              <input id="comment-mode-question" class="comment-mode-switch__input" type="radio" name="comment_mode" checked>
              <label class="comment-mode-switch__label" for="comment-mode-question"><strong>質問する</strong><span>外部/利用者にも見えるQ&amp;A</span></label>
              <input id="comment-mode-review" class="comment-mode-switch__input" type="radio" name="comment_mode">
              <label class="comment-mode-switch__label" for="comment-mode-review"><strong>確認事項を残す</strong><span>内部向けの確認・指摘・修正依頼</span></label>
              <div class="comment-mode-switch__panel comment-mode-switch__panel--question">
                <textarea rows="4" placeholder="この文書について確認したいことを書いてください"></textarea>
                <p class="actions"><button class="button">質問を投稿</button></p>
              </div>
            </div>
          </div>

          <div class="document-comment-search card">
            <h3>コメントを検索</h3>
            <div class="form-grid form-grid--compact">
              <label class="form-field--full">コメント本文 / 位置メモ<input type="search" value="修正依頼"></label>
            </div>
            <p class="actions form-actions"><button class="button secondary">コメントを検索</button><a class="button secondary" href="#">検索を解除</a></p>
          </div>

          <div class="document-comment-tabs card">
            <input id="document-comment-tab-all" class="document-comment-tabs__input" type="radio" name="document_comment_tab" checked>
            <label class="document-comment-tabs__label" for="document-comment-tab-all">すべて</label>
            <input id="document-comment-tab-qa" class="document-comment-tabs__input" type="radio" name="document_comment_tab">
            <label class="document-comment-tabs__label" for="document-comment-tab-qa">Q&amp;A <span class="muted">(未解決 1)</span></label>
            <input id="document-comment-tab-review" class="document-comment-tabs__input" type="radio" name="document_comment_tab">
            <label class="document-comment-tabs__label" for="document-comment-tab-review">確認事項 <span class="muted">(未解決 1)</span></label>
            <input id="document-comment-tab-unresolved" class="document-comment-tabs__input" type="radio" name="document_comment_tab">
            <label class="document-comment-tabs__label" for="document-comment-tab-unresolved">未解決 <span class="muted">(2)</span></label>
            <div class="document-comment-tabs__panel document-comment-tabs__panel--all"><p class="muted">代表コメント</p></div>
          </div>
        </div>
      </details>
    HTML
  end

  def browser_checks_script(variant, viewport_name)
    <<~JS
      const failures = [];
      const viewport = window.innerWidth;
      const documentWidth = document.documentElement.scrollWidth;
      if (documentWidth > viewport + 1) failures.push(`horizontal overflow ${documentWidth} > ${viewport}`);

      const requiredSelectors = [
        ".document-comment-workspace__panel",
        ".document-comment-workspace__header",
        ".document-comment-workspace__summary",
        ".document-comment-workspace__mode",
        ".document-comment-search",
        ".document-comment-tabs"
      ];

      const rectFor = (selector) => {
        const element = document.querySelector(selector);
        if (!element) {
          failures.push(`missing ${selector}`);
          return null;
        }
        const rect = element.getBoundingClientRect();
        if (rect.width <= 0 || rect.height <= 0) failures.push(`not visible ${selector}`);
        return rect;
      };

      const panel = rectFor(".document-comment-workspace__panel");
      if (panel) {
        if (panel.left < -1) failures.push(`panel left overflow ${panel.left}`);
        if (panel.right > viewport + 1) failures.push(`panel right overflow ${panel.right} > ${viewport}`);
      }

      const ordered = requiredSelectors.slice(1).map(rectFor).filter(Boolean);
      for (let index = 1; index < ordered.length; index += 1) {
        if (ordered[index].top < ordered[index - 1].bottom - 1) {
          failures.push(`vertical overlap after ${requiredSelectors[index]}`);
        }
      }

      const labels = Array.from(document.querySelectorAll(".document-comment-tabs__label,.comment-mode-switch__label"));
      labels.forEach((label) => {
        const rect = label.getBoundingClientRect();
        if (rect.right > viewport + 1) failures.push(`label overflow ${label.textContent.trim()}`);
      });

      return failures;
    JS
  end
end
