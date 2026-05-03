module SeedSupport
  class DocusaurusMarkdownNormalizer
    MARKDOWN_EXTENSIONS = %w[.md .markdown].freeze

    def initialize(markdown:, generated_id:)
      @markdown = markdown
      @generated_id = generated_id
    end

    def normalize
      front_matter, body = split_front_matter(@markdown)
      body = rewrite_local_markdown_links_for_seed(body)
      body = sanitize_markdown_for_mdx(body)

      if front_matter
        build_markdown_with_front_matter(front_matter, body)
      else
        <<~MARKDOWN
          ---
          id: #{@generated_id}
          ---

          #{body}
        MARKDOWN
      end
    end

    private

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

    def build_markdown_with_front_matter(front_matter, body)
      lines = front_matter.lines
      lines = lines.reject { _1.match?(/\A\s*id:\s*/) }
      lines.insert(1, "id: #{@generated_id}\n")

      "#{lines.join}#{body}"
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
  end
end
