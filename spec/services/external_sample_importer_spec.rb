require "rails_helper"
require "fileutils"
require "securerandom"
require Rails.root.join("db/seeds/support/docusaurus_builder")
require Rails.root.join("db/seeds/support/external_sample_importer")

RSpec.describe SeedSupport::ExternalSampleImporter do
  let(:root) { Rails.root.join("tmp", "external-sample-importer-#{SecureRandom.hex(4)}") }
  let(:context) do
    Class.new do
      def child_directories(path)
        path.children.select(&:directory?).sort_by(&:to_s)
      end

      def project_code_for_sample_set(_sample_set_key)
        "EXT_SAMPLE"
      end

      def version_snapshot_directory?(_path)
        false
      end

      def relative_path(path, root)
        Pathname(path).relative_path_from(Pathname(root)).to_s
      end

      def document_slug_for_markdown(_site_dir, logical_relative_path)
        Pathname(logical_relative_path.to_s).sub_ext("").to_s.tr("/", "-")
      end

      def version_label_for_name(name)
        name.to_s.presence || "current"
      end

      def slug_for_name(name)
        name.to_s.parameterize
      end

      def site_build_segment_for_name(name)
        slug_for_name(name.to_s.presence || "current")
      end

      def document_title_for_markdown(logical_relative_path, _site_dir)
        Pathname(logical_relative_path.to_s).basename.sub_ext("").to_s
      end

      def site_page_path_for_markdown(logical_relative_path, site_build_path)
        [site_build_path, Pathname(logical_relative_path.to_s).sub_ext("").to_s].join("/")
      end

      def related_attachment_files(source_file, logical_relative_path, _source_root)
        path = Pathname(logical_relative_path.to_s)
        source_path = Pathname(source_file)

        Dir.glob(source_path.dirname.join("#{path.basename.sub_ext('').to_s}.*").to_s)
          .select { File.file?(_1) }
          .reject { Pathname(_1) == source_path }
          .sort
      end
    end.new
  end

  before do
    FileUtils.mkdir_p(root.join("sample-set", "site", "diagrams"))
    File.write(root.join("sample-set", "site", "README.md"), "# Overview\n")
    File.write(root.join("sample-set", "site", "diagrams", "flow.puml"), "@startuml\nA -> B\n@enduml\n")
    File.write(root.join("sample-set", "site", "diagrams", "flow.png"), "image")
  end

  after do
    FileUtils.rm_rf(root)
  end

  it "scans markdown and standalone diagram files without changing File.extname" do
    documents = described_class.new(context).documents(root)
    logical_paths = documents.map { _1[:markdown_logical_relative_path] }

    expect(File.extname(root.join("sample-set", "site", "diagrams", "flow.puml"))).to eq(".puml")
    expect(logical_paths).to include("README.md")
    expect(logical_paths).to include("diagrams/flow.puml")
  end

  it "keeps a standalone diagram source file as an attachment" do
    documents = described_class.new(context).documents(root)
    diagram_document = documents.find { _1[:markdown_logical_relative_path] == "diagrams/flow.puml" }

    expect(diagram_document[:attachment_files].map { _1.basename.to_s }).to eq(%w[flow.puml flow.png])
  end
end
