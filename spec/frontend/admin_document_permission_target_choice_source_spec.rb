# frozen_string_literal: true

require "rails_helper"

RSpec.describe "admin document permission target choice source" do
  let(:form_source) { Rails.root.join("app/views/admin/document_permissions/_form.html.slim").read }
  let(:helper_source) { Rails.root.join("app/helpers/admin/document_permissions_helper.rb").read }

  it "keeps the company and user target choice guidance aligned with validation" do
    expect(form_source).to include("target_error_messages = document_permission_target_error_messages(document_permission)")
    expect(form_source).to include("適用対象の選択を確認してください。")
    expect(form_source).to include("会社全体に付与するか、特定ユーザー1名に付与するかを選びます。")
    expect(form_source).to include("会社全体に同じ権限を付与する場合だけ選択します。")
    expect(form_source).to include("特定の1名にだけ権限を付与する場合だけ選択します。")
    expect(form_source).to include("会社とユーザーはどちらか一方だけを指定してください。")
  end

  it "keeps target base errors available near the target section" do
    expect(helper_source).to include("def document_permission_target_error_messages(document_permission)")
    expect(helper_source).to include("company_id or user_id is required")
    expect(helper_source).to include("company_id and user_id cannot both be set")
    expect(helper_source).to include("DOCUMENT_PERMISSION_FORM_BASE_ERROR_MESSAGES.key?(error.message)")
  end

  it "does not change the document select remote-load error surface" do
    expect(form_source).to include("document-permission-error-surface")
    expect(form_source).to include("rails-fields-kit--tom-select:selected-load-error")
    expect(form_source).to include("error_surface_html: { class: \"notice alert\" }")
  end
end
