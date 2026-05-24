require "rails_helper"

RSpec.describe "Admin document sets Tom Select", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:project) { create(:project, name: "Delivery Project") }
  let!(:editable_document_set) do
    create(
      :document_set,
      project:,
      name: "編集中セット",
      set_type: :delivery,
      visibility_policy: :restricted_external,
      sort_order: 2,
      created_by: admin
    )
  end

  before do
    driven_by(:selenium_chrome_headless)
  end

  it "keeps rails fields kit selects initialized after turbo navigation" do
    sign_in_via_browser(admin)

    visit admin_root_path
    click_link "文書セット"

    expect(page).to have_current_path(admin_document_sets_path, ignore_query: true)
    expect(page).to have_css(".ts-wrapper", minimum: 3)

    click_link "編集", href: edit_admin_document_set_path(editable_document_set)

    expect(page).to have_current_path(edit_admin_document_set_path(editable_document_set), ignore_query: true)
    expect(page).to have_css(".ts-wrapper", minimum: 3)
  end

  def sign_in_via_browser(user, password: "password123!")
    visit new_session_path
    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: password
    click_button "ログイン"

    expect(page).to have_current_path(root_path, ignore_query: true)
  end
end
