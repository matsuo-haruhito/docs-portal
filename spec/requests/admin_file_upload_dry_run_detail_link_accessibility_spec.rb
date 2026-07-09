require "rails_helper"

RSpec.describe "Admin file upload dry-run detail link accessibility", type: :request do
  let(:admin_user) { create(:user, :internal) }
  let(:project) { create(:project, code: "FILEUI", name: "File UI Project") }

  def parsed_html
    Nokogiri::HTML(response.body)
  end

  def detail_links
    parsed_html.css("a").select { _1.text.squish == "詳細" }
  end

  it "keeps compact visible detail links while making each accessible name row-specific" do
    sign_in_as(admin_user)
    first_dry_run = create_file_upload_dry_run(
      result_json: {
        "file_upload_preview" => {
          "source_name" => "local-folder-sync",
          "relative_path" => "docs/README.md",
          "content_hash" => "abc123contenthash"
        }
      }
    )
    second_dry_run = create_file_upload_dry_run(
      result_json: {
        "file_upload_preview" => {
          "source_name" => "another-source",
          "relative_path" => "docs/SECOND.md",
          "content_hash" => "def456contenthash"
        }
      }
    )

    get admin_file_upload_dry_runs_path

    labels_by_href = detail_links.to_h { [_1["href"], _1["aria-label"]] }
    joined_labels = labels_by_href.values.join

    expect(response).to have_http_status(:ok)
    expect(detail_links.map { _1.text.squish }).to eq(["詳細", "詳細"])
    expect(labels_by_href.fetch(admin_file_upload_dry_run_path(first_dry_run))).to match(/\Adry-run #{Regexp.escape(first_dry_run.public_id)}（.+）の詳細を確認\z/)
    expect(labels_by_href.fetch(admin_file_upload_dry_run_path(second_dry_run))).to match(/\Adry-run #{Regexp.escape(second_dry_run.public_id)}（.+）の詳細を確認\z/)
    expect(labels_by_href.values).to contain_exactly(a_string_including(first_dry_run.public_id), a_string_including(second_dry_run.public_id))
    expect(joined_labels).not_to include("docs/README.md")
    expect(joined_labels).not_to include("docs/SECOND.md")
    expect(joined_labels).not_to include("abc123contenthash")
    expect(joined_labels).not_to include("def456contenthash")
  end

  private

  def create_file_upload_dry_run(result_json: {})
    ImportDryRun.create!(
      import_mode: :manual_upload,
      status: :analyzed,
      project:,
      created_by: admin_user,
      source_commit_hash: "abc123sourcecommit",
      summary_json: { "total" => 1, "create_count" => 1, "update_count" => 0, "warning_count" => 0 },
      result_json: default_result_json.merge(result_json),
      warnings_json: [],
      errors_json: []
    )
  end

  def default_result_json
    {
      "artifact_root" => "/tmp/file-upload-artifact",
      "manifest_path" => "/tmp/file-upload-artifact/manifest.json",
      "items" => [
        {
          "source_path" => "docs/README.md",
          "title" => "README",
          "action" => "create"
        }
      ],
      "file_upload_preview" => {
        "source_name" => "local-folder-sync",
        "relative_path" => "docs/README.md",
        "source_path" => "C:/work/customer-docs/docs/README.md",
        "file_size" => 1234,
        "content_hash" => "abc123contenthash",
        "source_commit_hash" => "abc123sourcecommit",
        "version_label" => "file-v1",
        "zip_import_preview" => { "warnings" => [] }
      }
    }
  end
end
