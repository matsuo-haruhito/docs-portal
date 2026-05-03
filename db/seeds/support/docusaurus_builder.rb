require "digest"
require "fileutils"
require "cgi"
require "open3"
require "tmpdir"

module SeedSupport
  module SeedDiagramFileExtnamePatch
    def extname(path)
      if SeedSupport::DocusaurusBuilder.seed_diagram_file_candidate?(path)
        ".md"
      else
        super
      end
    end
  end

  class DocusaurusBuilder
    BUILD_ROOT = Rails.root.join("docusaurus")

    MARKDOWN_EXTENSIONS = %w[.md .markdown].freeze
    DIAGRAM_FILE_LANGUAGES = {
      ".puml" => "plantuml",
      ".plantuml" => "plantuml",
      ".d2" => "d2",
      ".mmd" => "mermaid",
      ".mermaid" => "mermaid"
    }.freeze
    KROKI_DIAGRAM_LANGUAGES = %w[plantuml d2].freeze
    LOCAL_ASSET_EXTENSIONS = %w[
      .png .jpg .jpeg .gif .webp .svg .bmp .ico .avif
    ].freeze
    DIAGRAM_FENCE_PATTERN = /\A\s{0,3}(```|~~~)\s*(plantuml|puml|d2)(?:\s|\z)/i

    def initialize(source_dir:, version:, site_build_path:)
      @source_dir = Pathname(source_dir)
      @version = version
      @site_build_path = site_build_path
    end

    def build
      return unless renderable_document_files?

      validate_kroki_endpoint!

      with_temp_workspace do |workspace|
        docs_src = workspace.join("docs-src")
        build_output_dir = workspace.join("build")
        populate_docs_src!(docs_src)
        run_build!(docs_src, build_output_dir)
        copy_build!(build_output_dir)
        build_route_map
      end
    end

    def self.seed_doc_id_for(relative)
      digest = Digest::SHA1.hexdigest(relative.to_s)[0, 12]
      "seed-#{digest}"
    end

    def self.markdown_file?(path)
      MARKDOWN_EXTENSIONS.include?(Pathname(path).extname.downcase)
    end

    def self.diagram_file?(path)
      DIAGRAM_FILE_LANGUAGES.key?(Pathname(path).extname.downcase)
    end

    def self.diagram_language_for(path)
      DIAGRAM_FILE_LANGUAGES.fetch(Pathname(path).extname.downcase)
    end

    def self.renderable_document_file?(path)
      markdown_file?(path) || diagram_file?(path)
    end

    def self.install_seed_diagram_extname_patch!
      return if @seed_diagram_extname_patch_installed

      File.singleton_class.prepend(SeedDiagramFileExtnamePatch)
      @seed_diagram_extname_patch_installed = true
    end

    def self.seed_diagram_file_candidate?(path)
      value = path.to_s.tr("\\", "/")
      return false unless value.include?("/storage/document_files/external_samples/")

      diagram_file?(value)
    end

    private

    def renderable_document_files?
      Dir.glob(@source_dir.join("**/*").to_s).any? do |path|
        source = Pathname(path)
        source.file? && self.class.renderable_document_file?(source)
      end
    end

    def markdown_file?(path)
      self.class.markdown_file?(path)
    end

    def diagram_file?(path)
      self.class.diagram_file?(path)
    end

    def diagram_language_for(path)
      self.class.diagram_language_for(path)
    end

    def local_asset_file?(path)
      LOCAL_ASSET_EXTENSIONS.include?(path.extname.downcase)
    end

    def validate_kroki_endpoint!
      return if ENV["KROKI_ENDPOINT"].to_s.strip.present?

      diagram_files = files_requiring_kroki
      return if diagram_files.empty?

      message = [
        "KROKI_ENDPOINT is required because seed documents contain PlantUML/D2 diagrams.",
        "",
        "Set these values in .env when using the optional Kroki compose file:",
        "  COMPOSE_FILE=docker-compose.yml:docker-compose.kroki.yml",
        "  KROKI_ENDPOINT=http://kroki:8000",
        "",
        "Diagram files:",
        *diagram_files.first(10).map { |path| "  - #{path}" }
      ].join("\n")

      raise message
    end

    def files_requiring_kroki
      Dir.glob(@source_dir.join("**/*").to_s).sort.filter_map do |path|
        source = Pathname(path)
        next unless source.file?

        if markdown_file?(source)
          next unless markdown_contains_diagram?(source)
        elsif diagram_file?(source)
          next unless KROKI_DIAGRAM_LANGUAGES.include?(diagram_language_for(source))
        else
          next
        end

        source.relative_path_from(@source_dir).to_s
      end
    end

    def markdown_contains_diagram?(source)
      File.foreach(source).any? { |line| line.match?(DIAGRAM_FENCE_PATTERN) }
    end

    def with_temp_workspace
      Dir.mktmpdir("seed-docusaurus-") do |tmp_dir|
        yield Pathname(tmp_dir)
      end
    end

    def populate_docs_src!(docs_src)
      root = docs_src.join(@site_build_path)
      FileUtils.mkdir_p(root)

      Dir.glob(@source_dir.join("**/*").to_s).sort.each do |path|
        source = Pathname(path)
        next unless source.file?

        relative = source.relative_path_from(@source_dir)

        if markdown_file?(source)
          destination = root.join(normalized_doc_relative_path(relative))
          FileUtils.mkdir_p(destination.dirname)
          write_markdown_with_seed_front_matter!(source, destination, relative)
        elsif diagram_file?(source)
          destination = root.join(normalized_doc_relative_path(relative))
          FileUtils.mkdir_p(destination.dirname)
          write_diagram_wrapper_markdown!(source, destination, relative)
        elsif local_asset_file?(source)
          destination = root.join(relative)
          FileUtils.mkdir_p(destination.dirname)
          FileUtils.cp(source, destination)
        end
      end
    end

    def write_markdown_with_seed_front_matter!(source, destination, relative)
      original = File.read(source)
      front_matter, body = split_front_matter(original)

      body = rewrite_local_markdown_links_for_seed(body)
      body = sanitize_markdown_for_mdx(body)

      generated_id = seed_doc_id(relative)

      destination.write(
        if front_matter
          build_markdown_with_front_matter(front_matter, body, generated_id)
        else
          <<~MARKDOWN
            ---
            id: #{generated_id}
            ---

            #{body}
          MARKDOWN
        end
      )
    end

    def write_diagram_wrapper_markdown!(source, destination, relative)
      language = diagram_language_for(source)
      title = relative.basename.sub_ext("").to_s
      body = File.read(source)

      destination.write(<<~MARKDOWN)
        ---
        id: #{seed_doc_id(relative)}
        ---

        # #{title}

        ```#{language}
        #{body}
        ```
      MARKDOWN
    end

    def split_front_matter(markdown)
      return [nil, markdown] unless markdown.start_with?("---\n")

      lines = markdown.lines
      closing_index = lines[1..].find_index { _1.strip == "---" }
      return [nil, markdown] unless closing_index

      closing_index += 1
      front_matter = lines[0..closing_index].join
      body = (lines[(closing_index + 1)..] || []).join

      [front_matter, body]
    end

    def build_markdown_with_front_matter(front_matter, body, generated_id)
      lines = front_matter.lines
      lines = lines.reject { _1.match?(/\A\s*id:\s*/) }
      lines.insert(1, "id: #{generated_id}\n")

      "#{lines.join}#{body}"
    end

    def seed_doc_id(relative)
      self.class.seed_doc_id_for(relative)
    end

    def rewrite_local_markdown_links_for_seed(body)
      body.gsub(/\]\(([^)]+)\)/) do
        url = Regexp.last_match(1)
        rewritten_url = rewrite_local_markdown_url_for_seed(url)

        "](#{rewritten_url})"
      end
    end

    def rewrite_local_markdown_url_for_seed(url)
      return url if external_url?(url)
      return url if url.start_with?("#")
      return url unless markdown_url?(url)

      path, anchor = url.split("#", 2)
      rewritten_path =
        if path.match?(/(^|\/)README\.(md|markdown)\z/i)
          path.sub(/README\.(md|markdown)\z/i, "index.md")
        else
          path
        end

      [rewritten_path, anchor].compact.join("#")
    end

    def external_url?(url)
      url.start_with?(
        "http://",
        "https://",
        "//",
        "mailto:",
        "tel:",
        "file:",
        "data:"
      )
    end

    def markdown_url?(url)
      path = url.split("#", 2).first.to_s
      MARKDOWN_EXTENSIONS.include?(File.extname(path).downcase)
    end

    def sanitize_markdown_for_mdx(body)
      in_fenced_code_block = false

      body.lines.map do |line|
        stripped = line.lstrip

        if stripped.start_with?("```", "~~~")
          in_fenced_code_block = !in_fenced_code_block
          next line
        end

        next line if in_fenced_code_block
        next line if line.match?(/\A\s{4}/)

        escape_mdx_angle_brackets(line)
      end.join
    end

    def escape_mdx_angle_brackets(line)
      line
        .gsub("<", "&lt;")
        .gsub(">", "&gt;")
    end

    def normalized_doc_relative_path(relative)
      basename = relative.basename.to_s
      normalized_basename =
        if basename.match?(/\AREADME\.(md|markdown)\z/i)
          "index.md"
        elsif diagram_file?(relative)
          "#{relative.basename.sub_ext("")}.md"
        else
          basename
        end

      relative.dirname.join(normalized_basename)
    end

    def run_build!(docs_src, build_output_dir)
      env = {
        "DOCUSAURUS_DOCS_PATH" => docs_src.to_s
      }

      stdout, stderr, status = Open3.capture3(
        env,
        "npm", "run", "build", "--", "--out-dir", build_output_dir.to_s,
        chdir: BUILD_ROOT.to_s
      )

      return if status.success?

      raise "Docusaurus build failed for #{@source_dir}: #{stderr.presence || stdout}"
    end

    def copy_build!(build_output_dir)
      destination = @version.site_root_absolute_path
      FileUtils.mkdir_p(destination)
      FileUtils.rm_rf(destination.children)
      FileUtils.cp_r(build_output_dir.children, destination)

      return if @version.site_entry_absolute_path&.exist?

      raise "Seed Docusaurus build output missing entry path: #{@site_build_path}"
    end

    def build_route_map
      Dir.glob(@version.site_root_absolute_path.join("**/index.html").to_s).each_with_object({}) do |html_path, result|
        relative_path = Pathname(html_path).relative_path_from(@version.site_root_absolute_path).to_s
        route_path = relative_path.delete_suffix("/index.html")
        route_path = @site_build_path if route_path.blank?

        html = File.read(html_path)
        doc_ids = html.scan(/docs-doc-id-([^"\s]+)/).flatten
        next if doc_ids.empty?

        doc_ids.each do |doc_id|
          decoded_doc_id = CGI.unescapeHTML(doc_id)
          result[decoded_doc_id] ||= route_path
          generated_id = decoded_doc_id.split("/").last
          result[generated_id] ||= route_path
        end
      end
    end
  end
end

if caller_locations.any? { _1.path.end_with?("/db/seeds.rb") }
  SeedSupport::DocusaurusBuilder.install_seed_diagram_extname_patch!
end
