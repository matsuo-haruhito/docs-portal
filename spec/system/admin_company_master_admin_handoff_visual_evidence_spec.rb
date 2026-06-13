require "rails_helper"
require "capybara/rspec"

RSpec.describe "Company master admin handoff visual evidence", type: :system do
  let(:company) { create(:company, name: "Acme Docs", domain: "acme.example") }
  let(:company_admin) do
    create(
      :user,
      :company_master_admin,
      company: company,
      name: "Company Admin",
      email_address: "company-admin@acme.example"
    )
  end

  before do
    driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 900])
  end

  it "keeps the handoff interaction readable on desktop" do
    sign_in_through_browser
    visit admin_root_path

    within_handoff_section do
      expect(page).to have_text("internal admin へ依頼するときの確認項目")
      expect(page).to have_text("案件・案件所属")
      expect(page).to have_text("文書・文書権限")
      expect(page).to have_text("運用確認")
      expect(page).to have_text("管理者判断")

      choose "文書・文書権限", allow_label_click: true
      expect(copy_target_value).to include("【分類】文書・文書権限")
      expect(copy_target_value).to include("【依頼内容】文書管理、閲覧範囲、文書公開権限の調整など")
      expect(copy_target_value).to include("【確認項目】文書名、必要な閲覧範囲、公開権限、対象ユーザー")

      find('[data-company-master-admin-handoff-target="targetUser"]').set("山田花子 / hanako@example.com")
      find('[data-company-master-admin-handoff-target="requestDetail"]').set("文書閲覧範囲を確認したい")
      find('[data-company-master-admin-handoff-target="checklist"]').set("対象文書と公開範囲")
      find('[data-company-master-admin-handoff-target="timeline"]').set("月曜の定例前")

      expect(copy_target_value).to include("【対象ユーザー】山田花子 / hanako@example.com")
      expect(copy_target_value).to include("【依頼内容】文書閲覧範囲を確認したい")
      expect(copy_target_value).to include("【確認項目】対象文書と公開範囲")
      expect(copy_target_value).to include("【期限・背景】月曜の定例前")

      disable_clipboard_api
      click_button "依頼テンプレートをコピー"
      expect(page).to have_css("#company-master-admin-handoff-status", text: "コピー機能を使えません。テンプレートを選択してコピーしてください。", visible: :visible)
    end

    expect_handoff_to_fit_viewport
  end

  it "keeps the handoff controls readable on a narrow viewport" do
    page.current_window.resize_to(390, 900)

    sign_in_through_browser
    visit admin_root_path

    within_handoff_section do
      expect(page).to have_text("依頼分類")
      expect(page).to have_text("対象ユーザー")
      expect(page).to have_text("依頼内容")
      expect(page).to have_text("確認項目")
      expect(page).to have_text("依頼テンプレートをコピー")
      expect(page).to have_text("連絡先や forbidden admin surface への direct link はここでは固定しません")

      choose "管理者判断", allow_label_click: true
      expect(copy_target_value).to include("【分類】管理者判断")
      expect(copy_target_value).to include("【user type 変更相談】あり")
    end

    expect_handoff_to_fit_viewport
  end

  def sign_in_through_browser
    visit new_session_path
    fill_in "メールアドレス", with: company_admin.email_address
    fill_in "パスワード", with: "password123!"
    click_button "ログイン"
    expect(page).to have_text("ログインしました。")
  end

  def within_handoff_section(&block)
    within('section[data-controller="company-master-admin-handoff"]', &block)
  end

  def copy_target_value
    find('textarea.company-master-admin-handoff-template').value
  end

  def disable_clipboard_api
    page.execute_script(<<~JS)
      Object.defineProperty(navigator, "clipboard", { value: undefined, configurable: true });
    JS
  end

  def expect_handoff_to_fit_viewport
    viewport_evidence = page.evaluate_script(<<~JS)
      (function() {
        var section = document.querySelector('section[data-controller="company-master-admin-handoff"]');
        var checkedNodes = [section].concat(Array.prototype.slice.call(section.querySelectorAll('fieldset label, input, textarea, button')));
        var sectionRect = section.getBoundingClientRect();
        var visibleNodes = checkedNodes.every(function(node) {
          var rect = node.getBoundingClientRect();
          return rect.width > 0 && rect.height > 0 && rect.left < window.innerWidth && rect.right > 0;
        });

        return {
          visibleNodes: visibleNodes,
          sectionWithinViewport: sectionRect.left >= 0 && sectionRect.right <= window.innerWidth + 1,
          sectionDoesNotOverflow: section.scrollWidth <= section.clientWidth + 1
        };
      })();
    JS

    aggregate_failures do
      expect(viewport_evidence["visibleNodes"]).to eq(true)
      expect(viewport_evidence["sectionWithinViewport"]).to eq(true)
      expect(viewport_evidence["sectionDoesNotOverflow"]).to eq(true)
    end
  end
end
