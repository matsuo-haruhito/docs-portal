require "rails_helper"

RSpec.describe "Company master admin handoff visual evidence", type: :request do
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

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def handoff_section
    parsed_html.at_css('section[data-controller="company-master-admin-handoff"]')
  end

  def handoff_text
    handoff_section.text.squish
  end

  before do
    sign_in_as(company_admin)
    get admin_root_path
  end

  it "renders the planned handoff surface for company_master_admin" do
    expect(response).to have_http_status(:ok)
    expect(handoff_section).to be_present

    aggregate_failures do
      expect(parsed_html.at_css("h1").text).to include("会社・ユーザー管理")
      expect(handoff_text).to include("internal admin へ依頼するときの確認項目")
      expect(handoff_text).to include("連絡先や forbidden admin surface への direct link はここでは固定しません")
      expect(handoff_text).to include("この確認項目は依頼内容を整理するためのものであり、会社管理者の権限や文書閲覧範囲を広げるものではありません")
    end
  end

  it "renders the four category choices as one browser-visible radio group" do
    categories = handoff_section.css('input[name="company_master_admin_handoff_category"]')
    category_labels = categories.map { |input| input.parent.text.squish }

    aggregate_failures do
      expect(categories.size).to eq(4)
      expect(categories.map { |input| input["data-action"] }.uniq).to eq(["company-master-admin-handoff#selectCategory"])
      expect(category_labels).to include(include("案件・案件所属"))
      expect(category_labels).to include(include("文書・文書権限"))
      expect(category_labels).to include(include("運用確認"))
      expect(category_labels).to include(include("管理者判断"))
      expect(category_labels).to include(include("案件の作成、所属追加、担当者の付け替えなど"))
      expect(category_labels).to include(include("ユーザー種別の internal 化、他社ユーザーや他社会社の調整など"))
    end
  end

  it "renders editable fields and the copy operation block in the same handoff section" do
    aggregate_failures do
      expect(handoff_section.at_css('[data-company-master-admin-handoff-target="targetUser"]')).to be_present
      expect(handoff_section.at_css('[data-company-master-admin-handoff-target="userType"]')).to be_present
      expect(handoff_section.at_css('[data-company-master-admin-handoff-target="requestDetail"]')).to be_present
      expect(handoff_section.at_css('[data-company-master-admin-handoff-target="checklist"]')).to be_present
      expect(handoff_section.at_css('[data-company-master-admin-handoff-target="timeline"]')).to be_present
      expect(handoff_section.css('[data-action="input->company-master-admin-handoff#updateTemplate"]').size).to eq(5)
      expect(handoff_section.at_css('button[aria-describedby="company-master-admin-handoff-status"]').text.squish).to eq("依頼テンプレートをコピー")
      expect(handoff_section.at_css('#company-master-admin-handoff-status[role="status"][aria-live="polite"]')).to be_present
      expect(handoff_section.at_css('textarea.company-master-admin-handoff-template[data-company-master-admin-handoff-target="template"]')).to be_present
    end
  end

  it "renders a copy target that contains the expected handoff labels" do
    template_text = handoff_section.at_css('textarea.company-master-admin-handoff-template').text

    aggregate_failures do
      expect(template_text).to include("【会社】Acme Docs")
      expect(template_text).to include("【依頼者】Company Admin / company-admin@acme.example")
      expect(template_text).to include("【分類】案件・案件所属")
      expect(template_text).to include("【対象ユーザー】名前 / メールアドレス")
      expect(template_text).to include("【依頼内容】案件の作成、所属追加、担当者の付け替えなど")
      expect(template_text).to include("【確認項目】案件名、対象ユーザー、必要な役割、担当者変更の有無")
      expect(template_text).to include("【user type 変更相談】なし")
      expect(template_text).to include("【期限・背景】理由と希望時期")
    end
  end
end
