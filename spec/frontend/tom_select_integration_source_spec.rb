require "rails_helper"

RSpec.describe "Tom Select integration source" do
  it "keeps document set form selects on rails fields kit helpers" do
    form_source = Rails.root.join("app/views/admin/document_sets/_form.html.slim").read

    expect(form_source).to include("= form.rfk_select :project_id,")
    expect(form_source).to include("= form.rfk_select :set_type,")
    expect(form_source).to include("= form.rfk_select :visibility_policy,")
  end

  it "registers the rails fields kit controller without calling the legacy shim" do
    entrypoint_source = Rails.root.join("app/frontend/entrypoints/application.js").read

    expect(entrypoint_source).to include('import { TomSelectController } from "rails_fields_kit"')
    expect(entrypoint_source).to include('application.register("rails-fields-kit--tom-select", TomSelectController)')
    expect(entrypoint_source).not_to include("setupTomSelectFields")
  end

  it "keeps the legacy export as a no-op compatibility shim" do
    shim_source = Rails.root.join("app/frontend/lib/tom_select_fields.js").read

    expect(shim_source).to include("compatibility shim")
    expect(shim_source).to include("export function setupTomSelectFields(_root = document) {}")
    expect(shim_source).not_to include("turbo:load")
    expect(shim_source).not_to include("addEventListener")
  end
end

RSpec.describe "Admin document sets Tom Select", type: :system do
  driven_by(:selenium, using: :headless_chrome, screen_size: [1400, 1400])

  let!(:admin) { create(:user, :admin, email_address: "admin-system@example.com") }
  let!(:project) { create(:project, name: "Delivery Project") }
  let!(:existing_document_set) { create(:document_set, project:, name: "既存セット") }

  def sign_in_via_browser(user)
    visit new_session_path

    fill_in "メールアドレス", with: user.email_address
    fill_in "パスワード", with: "password123!"
    click_button "ログイン"

    expect(page).to have_current_path(projects_path, ignore_query: true)
  end

  def expect_tom_select_initialized(field_id)
    expect(page).to have_css("select##{field_id}.tomselected", visible: :all)
    expect(page).to have_css("select##{field_id} + .ts-wrapper", visible: :all)
  end

  it "keeps rails fields kit selects initialized after a turbo invalid rerender" do
    sign_in_via_browser(admin)

    visit admin_document_sets_path

    expect(page).to have_current_path(admin_document_sets_path, ignore_query: true)
    expect_tom_select_initialized("document_set_project_id")
    expect_tom_select_initialized("document_set_set_type")
    expect_tom_select_initialized("document_set_visibility_policy")

    find("select#document_set_project_id + .ts-wrapper .ts-control", visible: :all).click
    find(".ts-dropdown .option", text: project.name).click
    fill_in "名称", with: existing_document_set.name
    click_button "保存"

    expect(page).to have_current_path(admin_document_sets_path, ignore_query: true)
    expect(page).to have_content("入力内容を確認してください。")
    expect_tom_select_initialized("document_set_project_id")
    expect_tom_select_initialized("document_set_set_type")
    expect_tom_select_initialized("document_set_visibility_policy")
  end
end
