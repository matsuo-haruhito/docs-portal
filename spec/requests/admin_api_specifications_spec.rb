require "rails_helper"

RSpec.describe "Admin API specifications", type: :request do
  let(:admin_user) { create(:user, :internal) }

  it "shows the API specification page from the admin menu" do
    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("API仕様")
    expect(response.body).to include("docs-src/api-specification.md")
    expect(response.body).to include("単体ファイルアップロードAPI")
    expect(response.body).to include("client-file-upload-api")
    expect(response.body).to include("主要ページとsource")
    expect(response.body).to include("docs-src/client-file-upload-api.md")
  end

  it "shows the available HTML status when the build is current" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("HTML表示可能")
    expect(response.body).to include("built HTML を表示できます")
  end

  it "notifies the admin when a stale API specification build is enqueued" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(true)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Docusaurus build を開始しました")
    expect(response.body).to include("build待ち")
  end

  it "shows when the source is newer than the rendered HTML" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(true)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("source更新あり")
    expect(response.body).to include("表示中のHTMLは古い可能性があります")
  end

  it "shows when the rendered HTML has not been generated yet" do
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:available?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:stale?).and_return(false)
    allow_any_instance_of(Admin::ApiSpecificationPage).to receive(:enqueue_build_if_stale!).and_return(false)

    sign_in_as(admin_user)

    get admin_api_specification_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("HTML未生成")
    expect(response.body).to include("Docusaurus build が必要です")
  end
end